# Delhivery Local (Hyperlocal) — Integration Plan

How Amal Foods will hand deliveries to Delhivery's riders instead of (or as well
as) its own fleet. Based on *Delhivery Direct Intracity APIs contract V6* and the
*Delhivery Hyperlocal Services – Enterprise* deck, and on how our backend
dispatches orders today.

---

## 0. Blockers to clear with Delhivery first

| # | Question | Why it matters |
|---|---|---|
| 1 | **Ahmedabad service map** (which areas/pincodes they cover). Ahmedabad is on their live-city list; Indore is not, so Indore stays on own riders. | Our Ahmedabad zone polygon should cover only areas they serve, or orders fail with `424`. |
| 2 | Sandbox + prod **Client ID, Client Secret, Client Code**. | Required on every call. |
| 3 | **Webhook signature algorithm** for `X-WEBHOOK-SIGNATURE` (HMAC-SHA256? over raw body? hex or base64?). | The contract says "computed using the signature key and payload" but not how. Until confirmed we use the `xApiKey` option instead. |
| 4 | **Exact webhook body shape.** | The contract shows Track API responses, not a webhook sample. We assume the webhook body equals the Track API `data` object — needs confirming. |
| 5 | Is there a **sandbox rider simulator** to push an order through all states? | Otherwise end-to-end testing needs a real rider. |
| 6 | Can a rider be **requested ahead of food being ready** (`readyToShip: false` → Confirm later), and how long can an unconfirmed order sit? | Drives when we call Confirm (see §3.2). |
| 7 | Billing: wallet prepaid or monthly invoice? Cancellation charges after a rider is assigned? | Affects the finance report and the cancel policy. |
| 8 | Is the rider's mobile number always sent? (examples show `"mobileNumber": ""`) | Decides whether the customer app can show a Call button. |

---

## 1. What Delhivery gives us (from the contract)

| API | Method / path | Use |
|---|---|---|
| Create Token | `POST /core/api/v1/aaa/auth/client-credentials` | `{clientId, clientSecret, audience}` → Bearer token, **expires in 24 h** |
| Get Quote | `POST /local/api/proxy/v1/shipper/pricing/quote` | Fare + capacity + pickup/delivery TAT per vehicle; **424 if not serviceable** |
| Create Order | `POST /local/api/proxy/v1/shipper/orders/create` | Pickup, drop, `vehicleMode`, OTP config, `itemDetails`, `paymentType`, **webhook (mandatory)** → `order_id` like `CRN…` |
| Confirm Order | `POST /local/api/proxy/v1/shipper/orders/confirm` | `{orderId, readyToShip: true}` releases an order created with `readyToShip: false` |
| Track Order | `GET /local/api/proxy/v1/shipper/orders/{order_id}` | Full state, rider info + live location, fare, `trackingUrl` |
| Cancel Order | `POST /local/api/proxy/v1/shipper/orders/cancel` | `{orderId, cancellationReason}` — reason must be from a fixed list |

Every call needs headers `X-COREOS-ACCESS` (token), `X-COREOS-REQUEST-ID` (unique per
request), `X-CLIENT-CODE`. Base URLs:
- **Dev:** `https://delvjkninl.sandbox.getos1.com`
- **Prod:** `https://ztietgya0i.logistax.io`

Delhivery's state machine:

| `status` | `fulfilmentStatus` | Sent by |
|---|---|---|
| creating | pending | webhook + track |
| created | searching_for_agent | webhook + track |
| assigned | agent_assigned | webhook + track |
| assigned | at_pickup | **webhook only** |
| inProgress | out_for_delivery | webhook + track |
| inProgress | at_delivery | **webhook only** |
| delivered | order_delivered | webhook + track |
| cancelled | cancelled | webhook + track |

---

## 2. Where it plugs into our system

Today the restaurant accepting an order (`updateOrderStatusRestaurant` →
`confirmed`/`preparing`) calls **`tryAutoAssign(orderId)`**, which offers the
order to our own riders. Every other re-dispatch path (rider rejects, offer
timeout, watchdog) also goes through `tryAutoAssign`. That one function is the
seam.

```
Restaurant accepts ─► tryAutoAssign(orderId)
                          │
                          ▼
                 resolveDeliveryProvider(order)      ← new: per-zone setting
                   │                     │
             "own" │                     │ "delhivery"
                   ▼                     ▼
       existing rider dispatch    delhiveryDispatch.start(order)
                                         │  quote → create (readyToShip:false)
                                         │  → confirm at the right moment
                                         ▼
                Delhivery webhook ─► /api/v1/webhooks/delhivery ─► map state
                Track API poller  ─┘   ─► our orderStatus / deliveryPhase,
                                         socket + push to customer & restaurant
```

Our own-fleet code is untouched; a Delhivery order simply never enters it.

---

## 2A. Zone-wise setup (first zone: Ahmedabad)

Every delivery decision is made **per zone**, so Ahmedabad can run on Delhivery
while Indore stays on our own riders, and more cities can be switched on later
from the admin panel without a deploy.

### Which zone an order belongs to

The **restaurant's** zone (`restaurant.zoneId`), not the zone the app sends.
Delhivery picks up from the restaurant, so the pickup city is what decides the
provider. An order whose restaurant has no zone always goes to own fleet.

### Per-zone delivery settings — new table `FoodZoneDeliveryConfig` (1:1 with `FoodZone`)

| Setting | Values | Ahmedabad | Indore |
|---|---|---|---|
| `provider` | `own` · `delhivery` · `delhivery_then_own` · `own_then_delhivery` | **`delhivery`** | `own` (no row needed) |
| `vehicleMode` | `2-wheeler` · `3-wheeler` · `mini-3w` · … | `2-wheeler` | — |
| `assignTimeoutMin` | minutes to find a rider before giving up | 10 | — |
| `onNoRider` | `fallback_own` · `cancel_refund` · `notify_admin` | `notify_admin` (no own riders there) | — |
| `confirmPolicy` | `on_accept` · `prep_aligned` · `on_ready` | `prep_aligned` | — |
| `maxFare` | ₹ cap on Delhivery's quote; above it → `onNoRider` path | e.g. 120 | — |
| `checkServiceability` | quote at checkout to block undeliverable carts | `true` | — |
| `isEnabled` | kill switch | `true` | — |

A separate table instead of columns on `FoodZone` keeps zone geometry and
logistics apart, and a zone with no row means "own fleet, nothing changes" — so
every existing zone keeps working untouched.

### Routing logic

```js
const zoneId = order.restaurant.zoneId;
const cfg = zoneId && await getZoneDeliveryConfig(zoneId);   // cached 60 s

if (!cfg || !cfg.isEnabled || cfg.provider === 'own')       → own riders (today's code)
if (cfg.provider === 'delhivery')                            → Delhivery only
if (cfg.provider === 'delhivery_then_own')                   → Delhivery; on no-rider / 424 / outage → own
if (cfg.provider === 'own_then_delhivery')                   → own; if no own rider in N min → Delhivery
```

Credentials (client ID/secret/code) stay **global** in `.env` — one Delhivery
account covers every city; only behaviour varies by zone.

### Checkout serviceability (per zone)

For zones with `checkServiceability: true`, `/orders/calculate` calls the Quote
API (cached ~5 min per restaurant + rounded drop location). A `424 not
serviceable` blocks the order with "Delivery isn't available to this address
yet" **before** the customer pays, instead of failing after the restaurant has
cooked.

### What Ahmedabad needs before go-live

1. **Zone:** create the Ahmedabad zone polygon in admin (Zones), covering only
   areas Delhivery serves there (ask them for their Ahmedabad service map).
2. **Fees:** an Ahmedabad fee-settings row (what customers pay), set against
   Delhivery's typical quote so delivery isn't loss-making.
3. **Restaurants:** onboarded with exact lat/lng and mapped to the Ahmedabad zone.
4. **Delivery config:** `provider = delhivery`, settings as in the table above.
5. **Sandbox test** with an Ahmedabad pickup/drop pair, then pilot with a few
   restaurants and the kill switch ready.

### Admin panel — Zones → Edit → "Delivery" tab

Provider dropdown, vehicle, timeouts, no-rider policy, fare cap, serviceability
toggle, enable switch, plus a **"Test with Delhivery"** button that runs a quote
from the zone's centre to a nearby point and shows fare + TAT (or the 424), so
ops can check a zone works before turning it on.

---

## 3. Backend design

### 3.1 New module `src/modules/food/logistics/delhivery/`

| File | Responsibility |
|---|---|
| `delhivery.client.js` | HTTP client: base URL by env, headers, `X-COREOS-REQUEST-ID` = UUID, 10 s timeout, retry on 5xx/network (not on 4xx), **token cache** (refresh 1 h before the 24 h expiry; on a 401 refresh once and retry). |
| `delhivery.mapper.js` | Our order → Delhivery payload; Delhivery state → our state (pure functions, unit-tested). |
| `delhivery.service.js` | `quote`, `start` (create), `confirm`, `cancel`, `sync` (track), `applyUpdate` (shared by webhook + poller). |
| `delhivery.webhook.js` | Route + auth check + idempotent apply. |
| `delhivery.poller.js` | Runs in the existing **scheduler process**: every 60 s, `sync` every active Delhivery shipment whose last update is > 90 s old (webhooks are primary; this catches missed ones). |

### 3.2 Order lifecycle with Delhivery

1. **Restaurant accepts** → `tryAutoAssign` → provider is `delhivery`.
2. **Quote** (pickup = restaurant lat/lng, drop = customer lat/lng).
   - `424` not serviceable → fall back to own fleet (if the zone allows) or alert admin.
   - Pick the vehicle (`2-wheeler` for food) and record the quoted fare.
3. **Create** with `readyToShip: false`, `clientReferenceOrderId` = our `order_id`,
   `paymentType: "PrePaid"`, `vehicleMode: "2-wheeler"`,
   `itemDetails` = item names + subtotal,
   drop OTP **CLIENT_GENERATED** = our existing 4-digit `deliveryOtp` (so the
   customer shows the same code they already see in the app),
   pickup OTP **CLIENT_GENERATED** = a new 4-digit code shown in the restaurant app,
   `webhook: { url, xApiKey }`.
4. **Confirm** (`readyToShip: true`) so the rider arrives as the food is ready.
   Pickup TAT is ~15 min, so: confirm **immediately if prep time ≤ quote `pickupTat`**,
   otherwise at `preparing` + (prepTime − pickupTat), and **always** at
   `ready_for_pickup` at the latest. Configurable per zone.
5. **Webhooks / polling** move our order along (§3.3).
6. **Delivered** → mark the order delivered, run the normal completion path
   **minus** own-rider earnings/wallet/cash-limit steps, record final fare.
7. **No rider found**: if still `searching_for_agent` after N minutes (default 10),
   cancel at Delhivery with `"taking too long to assign a driver"` and fall back to
   own fleet, or cancel + refund — per zone setting. Admin is notified either way.

### 3.3 State mapping (Delhivery → ours)

| Delhivery `fulfilmentStatus` | Our `orderStatus` | Our `deliveryPhase` | Customer sees |
|---|---|---|---|
| pending / searching_for_agent | unchanged (confirmed/preparing) | — | "Finding a delivery partner" |
| agent_assigned | unchanged | en_route_to_pickup | Rider name, vehicle, live location |
| at_pickup | `reached_pickup` | at_pickup | "Rider at restaurant" |
| out_for_delivery | `picked_up` | en_route_to_drop | Live tracking |
| at_delivery | `reached_drop` | at_drop | "Rider has arrived — share OTP" |
| order_delivered | `delivered` | delivered | Delivered |
| cancelled (by Delhivery) | unchanged + re-dispatch / admin alert | — | "Reassigning…" |

Rules: apply only **forward** transitions (ignore stale/out-of-order webhooks);
de-duplicate by `(shipmentId, fulfilmentStatus, updatedAt)`; every applied change
goes through the existing `pushStatusHistory`, socket emit and FCM path, so the
apps need no new events.

`partnerInfo.location` is pushed through the existing `location-update` socket
event and RTDB node, so the current live map keeps working.

### 3.4 Cancellations from our side

| Our event | Delhivery call | Reason sent |
|---|---|---|
| Customer cancels before pickup | Cancel | `service is no longer required` |
| Restaurant rejects / admin cancels | Cancel | `service is no longer required` |
| No rider within N min | Cancel | `taking too long to assign a driver` |
| Rider past pickup ETA (pickup TAT breach) | Cancel + re-dispatch | `pickup tat breached` |
| After pickup | **No cancel** — escalate to admin | — |

### 3.5 Data model (one migration)

- `FoodOrder.deliveryProvider` — enum `own | delhivery`, default `own`.
- New `FoodDeliveryShipment` (1 per order attempt): `orderId`, `provider`,
  `providerOrderId` (CRN…, unique), `status`, `fulfilmentStatus`,
  `nextDestination`, `vehicleMode`, `quotedFare`, `finalFare`, `pickupOtp`,
  `riderName`, `riderPhone`, `vehicleNumber`, `vehicleType`, `riderLat/Lng`,
  `trackingUrl`, `confirmedAt`, `cancelledAt`, `cancellationReason`,
  `lastPayload` (JSON), timestamps.
- New `FoodDeliveryProviderEvent`: raw webhook/poll payloads for audit + idempotency.
- New `FoodZoneDeliveryConfig` (1:1 with `FoodZone`) — all per-zone delivery
  settings; see §2A.

### 3.6 Config (`Backend/.env`, never committed)

```
DELHIVERY_ENV=sandbox            # sandbox | production
DELHIVERY_CLIENT_ID=
DELHIVERY_CLIENT_SECRET=
DELHIVERY_CLIENT_CODE=
DELHIVERY_WEBHOOK_API_KEY=       # random 32+ chars; sent to Delhivery as xApiKey
PUBLIC_API_BASE_URL=https://amal.buytogetherindia.com   # webhook URL is built from this
```

### 3.7 Webhook endpoint

`POST /api/v1/webhooks/delhivery` (public, no user auth):
- Auth: header `X-Api-Key` must equal `DELHIVERY_WEBHOOK_API_KEY` (constant-time
  compare). Switch to `X-WEBHOOK-SIGNATURE` verification once Delhivery confirms
  the algorithm.
- Look up the shipment by `orderId` (CRN…); unknown → `200` + log (never 4xx, or
  Delhivery may retry forever).
- Store raw event, `applyUpdate`, reply `200` fast; heavy work (push, socket) is
  fire-and-forget.
- Nginx already proxies `/api/` — no server change needed.

### 3.8 Money

- **Customer delivery fee:** unchanged — still our zone fee bands. Delhivery's
  dynamic fare is a cost, not something passed straight to the customer.
- **Cost tracking:** `quotedFare` at create, `finalFare` from the delivered
  payload → new "Delivery cost vs fee" column in the admin finance report, so the
  margin per order is visible.
- **No rider payout** on Delhivery orders (skip earnings, wallet, cash limit, COD
  deposit). Delhivery bills us per their contract.
- **COD:** send all Delhivery orders as `PrePaid`. Cash orders stay on own fleet
  until Delhivery's cash remittance process is agreed.

---

## 4. App & panel changes

| Where | Change |
|---|---|
| **Admin panel** | Zones → Delivery provider setting per zone + assign timeout. New "Delhivery shipments" page: live list, status, rider, fare, tracking link, manual Cancel / Resend to Delhivery / Switch to own fleet. Credentials health check (token fetch OK / failing). |
| **Customer app (Flutter + web)** | Order payload gains `deliveryProvider` and `externalDelivery { riderName, riderPhone, vehicleNumber, vehicleType, trackingUrl, lat, lng }`. The tracking screen fills the existing rider card from it; Call is hidden when the phone is empty; "Open live tracking" opens `trackingUrl` as a fallback. Drop OTP screen is unchanged. |
| **Restaurant app** | For Delhivery orders: show "Delhivery rider" + the **pickup OTP** to give the rider, and rider ETA. |
| **Rider app** | No change — Delhivery orders never reach our riders. |

---

## 5. Phases

| Phase | Scope | Estimate |
|---|---|---|
| **1. Foundations** | Client + token cache, mapper with unit tests against the contract's sample payloads, migration, env config, sandbox smoke script (token → quote → create → track → cancel). | 2–3 days |
| **2. Dispatch flow** | Provider routing in `tryAutoAssign`, create/confirm/cancel lifecycle, webhook endpoint, poller, state mapping, no-rider fallback, cancellation hooks. | 4–5 days |
| **3. Apps & admin** | Order payload fields, admin zone setting + shipments page, restaurant pickup OTP, customer tracking card, Flutter spec update. | 3–4 days |
| **4. Sandbox E2E + pilot** | Full sandbox runs through every state, failure drills (401 token, 424, webhook loss → poller, rider cancel), then a pilot on one zone with `own_then_delhivery` fallback and a kill switch. | 2–3 days + pilot |

**Total: ~2.5–3 weeks** to pilot, assuming credentials and answers to §0 arrive early.

---

## 6. Testing

- **Unit:** mapper (every `fulfilmentStatus`, multi-stop ignored, out-of-order
  events), OTP precedence, cancel-reason mapping, token refresh on 401.
- **Contract:** replay the PDF's sample payloads through `applyUpdate`.
- **Integration (sandbox):** create → confirm → track → cancel; webhook delivery to
  the staging URL; poller recovery with webhooks disabled.
- **Failure drills:** Delhivery down (5xx) → own-fleet fallback; 424 not
  serviceable; no rider in N min; rider cancels after assignment; duplicate webhook.
- **Kill switch:** setting a zone back to `own` stops new Delhivery orders
  immediately; in-flight ones finish via webhooks/poller.

---

## 7. Risks

| Risk | Mitigation |
|---|---|
| Ahmedabad zone drawn wider than Delhivery's coverage | Draw the polygon from their service map; checkout serviceability check blocks the rest. |
| No own riders in Ahmedabad to fall back on | `onNoRider = notify_admin` + auto cancel/refund after a second timeout; keep the pilot small. |
| Webhook format/signature undocumented | `xApiKey` auth + poller as the source of truth until confirmed. |
| Rider arrives before food is ready / food waits for rider | Confirm-timing rule (§3.2 step 4), tuned during the pilot. |
| Dynamic pricing spikes (rain, peak) | Store quote per order; admin alert if fare > configurable cap; fallback to own fleet above the cap. |
| Delhivery outage | Automatic own-fleet fallback per zone; circuit breaker after consecutive failures. |
| Rider phone missing | Hide Call; show Delhivery tracking link. |

# Suvio — Backend Changes Required (prompt for the backend engineer/agent)

You are a Senior Backend Engineer on the Suvio food-delivery backend
(`/backend/food-backend/Backend`, Node/Express + MongoDB + Socket.IO + Firebase
RTDB/FCM). The **customer Flutter app is already fully integrated** against the
existing contracts. Your job is to close the gaps below so the app's
already-built features light up.

**Hard rules**
- Do **not** break existing response shapes or the `{ success, message, data }`
  envelope. The app parses `data` directly.
- Additive changes only unless a fix is explicitly required. Every field the app
  reads today must keep working.
- Do not remove the RTDB `active_orders/{orderMongoId}` node or the Socket.IO
  events the app listens to (`location-update`, `order_status_update`,
  `order_ready`, `delivery_drop_otp`).
- Where a change is a config/env/seed change (no code), say so.
- For each item: implement, then state the acceptance test.

Work in priority order. P0 = blocking real usage, P1 = visible feature gaps,
P2 = polish/data.

---

## P0 — Configuration & correctness (mostly not code)

### P0.1 — Enable Razorpay (payments are currently dead)
`RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` are unset on the deployment, so
`POST /food/orders` returns `razorpay: null` and every online order is stranded
in `pending_payment` until the sweeper deletes it. Wallet top-up
(`POST /food/user/wallet/topup/order`) has the same problem.

- Set the Razorpay live/test keys in the environment.
- Verify the webhook (`POST /api/v1/payments/webhook`) is registered in the
  Razorpay dashboard and its secret is configured — the app treats the webhook
  as the source of truth on client-verify failures.
- **Accept:** `POST /food/orders` with `paymentMethod: "razorpay"` returns a
  non-null `razorpay: { key, orderId, amount, currency }`; a completed payment
  moves the order out of `pending_payment`.

### P0.2 — Configure fee settings (bills are all ₹0)
`POST /food/orders/calculate` returns `tax`, `deliveryFee`, `platformFee`,
`packagingFee`, `deliveryFeeGst` all `0` because fee-settings aren't populated.
- Populate `GET /food/admin/fee-settings/public` (GST rate, platform fee,
  packaging, per-km/distance delivery fee, quick-delivery surcharge).
- **Accept:** `/calculate` for a real cart + saved address returns non-zero,
  correctly-computed fees, and `total = subtotal + packagingFee + deliveryFee +
  deliveryFeeGst + platformFee + tax − discount`.

### P0.3 — `verify-otp` is not idempotent within one second (E11000)
`POST /food/auth/user/verify-otp` mints a JWT whose only per-second entropy is
`iat`. Two verifies in the same second produce a **byte-identical** token, and
the unique index on `food_refresh_tokens.token` rejects the second with
`E11000 duplicate key error`. A user who double-taps "Verify" hits this.
- Add a random `jti` (or nonce) to the refresh-token JWT payload so two tokens
  minted in the same second differ, **or** upsert instead of insert on the
  refresh-token collection, **or** make verify-otp idempotent (return the
  existing valid session instead of erroring).
- **Accept:** calling verify-otp twice in the same second for the same phone
  succeeds both times (or the second returns the same session) — never E11000.

### P0.4 — Merchant identity for Razorpay / business settings
`GET /food/admin/business-settings/public` returns `companyName: "Switcheats"`
and empty `logo.url`. The app now overrides the Razorpay sheet name locally to
"Suvio", but statements/UPI still show the registered entity.
- Set `companyName` to the correct consumer brand and populate `logo.url` with a
  hosted PNG (the app can pass this to the Razorpay sheet as `image`).
- Ensure the Razorpay account's public business name matches the brand.
- **Accept:** business-settings returns the brand name + a reachable logo URL.

---

## P1 — Order-tracking data the app already renders but never receives

### P1.1 — Expose rider vehicle + photo + delivery count on the order
The tracking screen shows vehicle type/number, rider photo and "N deliveries",
but the order payload doesn't carry them. Root causes (verified):

- `deliveryPartner.model.js` **has** `vehicleType`, `vehicleName`,
  `vehicleNumber` (lines ~36–47) and `profilePhoto` (line ~59) — but the
  order read populates the wrong/missing fields:
  ```js
  // order.service.js:997  (the single-order GET the tracking screen uses)
  .populate("dispatch.deliveryPartnerId",
            "name fullName phone phoneNumber rating totalRatings profileImage avatar")
  ```
  `profileImage` / `avatar` **do not exist** on the model — the real field is
  `profilePhoto`, so the rider photo is never returned. Vehicle fields aren't
  selected at all.

- There is **no delivery-count field** on the model (only `totalRatings`), so
  "19k+ orders delivered" cannot be backed today.

**Do:**
1. Fix the populate select on **all three** order populates
   (`order.service.js:891`, `:997`, `:2045`) to:
   `"name fullName phone phoneNumber rating totalRatings profilePhoto vehicleType vehicleName vehicleNumber"`.
2. Add a maintained `totalDeliveries` (completed-order counter) to
   `deliveryPartner.model.js`, increment it on delivery completion, and include
   it in the populate select.
3. Keep the normalized order shape: surface these under
   `dispatch.deliveryPartnerId` (already an object) so the app's
   `DeliveryPartner.fromApi` can read `vehicleType`/`vehicleNumber`/`profilePhoto`/
   `totalDeliveries` without a shape change.
- **Accept:** `GET /food/orders/:id` for an order with an assigned rider returns
  `dispatch.deliveryPartnerId.{profilePhoto, vehicleType, vehicleNumber,
  totalDeliveries}` populated.

### P1.2 — FCM push on every order-status transition
The app has full FCM handling (foreground/background/terminated + deep-link to
`/orders/track/:id`) and listens for `data.type`. Today only `order_created`,
`order_created_pending_payment` and `payment_success` are documented; status
transitions are emitted over **Socket.IO only** (`order_status_update` in
`order-delivery.service.js`), so a backgrounded/terminated app gets no push.

**Do:** send an FCM data-message to the customer on **each** transition —
`confirmed`, `preparing`, `ready_for_pickup`, `picked_up`, `reached_drop`,
`delivered`, and every `cancelled_by_*` — with:
```json
{ "type": "order_status_update", "status": "<newStatus>",
  "orderId": "FOD-…", "orderMongoId": "<_id>",
  "title": "…", "body": "…", "link": "/food/user/orders/<_id>" }
```
Reuse the existing FCM sender and the customer's saved tokens
(`/fcm-tokens/mobile/save`). Keep the Socket.IO emit as-is (foreground path).
- **Accept:** with the app killed, moving an order to `preparing` /
  `picked_up` / `delivered` delivers a system notification that deep-links to
  the tracking screen.

### P1.3 — Confirm the RTDB polyline is always populated post-pickup
The app reads the encoded route + restaurant/customer coords from
`active_orders/{orderMongoId}` and draws it **once**; it never calls Google
Directions. Ensure the backend writes `polyline`, `restaurantLat/Lng`,
`customerLat/Lng` to that node as soon as the order is picked up (and refreshes
`polyline` only on a real re-route).
- **Accept:** for a picked-up order the RTDB node has a non-empty encoded
  `polyline` plus both endpoint coordinates.

---

## P1 — Missing endpoints the app has UI for

### P1.4 — Favorites / Wishlist (currently 404)
`GET /food/user/favorites` returns **404 HTML** — the route does not exist. The
app has a favorites repository written against these paths and currently falls
back to on-device storage (not synced across devices).

Add, under `/food/user` (Bearer):
| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/favorites` | — | `{ restaurantIds:[], foodIds:[], restaurants:[…], foods:[…] }` |
| POST | `/favorites/restaurants/:restaurantId` | — | `{ success:true }` |
| DELETE | `/favorites/restaurants/:restaurantId` | — | `{ success:true }` |
| POST | `/favorites/foods/:foodId` | — | `{ success:true }` |
| DELETE | `/favorites/foods/:foodId` | — | `{ success:true }` |

- **Accept:** toggling a favorite persists server-side and comes back in
  `GET /favorites` on another device/session.

### P1.5 — Real-time chat (Customer ↔ Delivery Partner, and ↔ Restaurant)
There are **no** chat/message/conversation routes and **no** chat socket events.
The app is ready to consume a chat API but currently only offers Call (native
dialer). Add:

**REST** (`/food/user`, Bearer):
- `GET /orders/:orderId/chat` → message history
  `[{ id, from:"customer|partner|restaurant", text, imageUrl?, createdAt, readAt? }]`
- `POST /orders/:orderId/chat` → `{ text, imageUrl? }` → created message
- `PATCH /orders/:orderId/chat/read` → mark received messages read

**Socket.IO** (same auth/rooms as tracking):
- emit `chat_message` to the counterpart room on send
- emit `chat_typing` for typing indicators
- emit `chat_read` for read receipts
- include unread counts in the order payload or a `chat_unread` event

Constraints: only allow chat while the order is active; partner identity comes
from `dispatch.deliveryPartnerId`. Image sharing optional (reuse the uploads
route). If restaurant chat is out of scope, ship partner chat first and say so.
- **Accept:** two authenticated clients on the same order exchange messages in
  real time with delivered/read state and an unread count.

### P1.6 — Tip the delivery partner
The tracking screen can show ₹20/₹30/₹50/custom tip buttons but hides them
because there's no endpoint. Add:
- `POST /food/orders/:orderId/tip` → `{ amount }` (> 0) → updated order/pricing,
  charged via the existing Razorpay flow (or added to the settlement).
- Reflect the tip in the delivery partner's earnings/settlement.
- **Accept:** a tip is accepted, charged, and attributed to the rider.

### P1.7 — Invoice / receipt
No invoice endpoint exists. Add one of:
- `GET /food/orders/:orderId/invoice` → a hosted PDF URL, **or**
- `GET /food/orders/:orderId/invoice` → structured invoice JSON (line items,
  taxes, fees, discount, total, restaurant + customer details, timestamps) the
  app can render/share.
- **Accept:** a delivered order returns a downloadable/renderable invoice.

---

## P2 — Data / seed hygiene

### P2.1 — Restaurant `openDays` naming
Seed data mixes full names (`"Friday"`) and abbreviations (`"Fri"`). The
normalizer handles both, but standardize the seed on full weekday names to avoid
edge cases in `outletTimings`.

### P2.2 — Seed rider vehicle + photo data
So P1.1 has something to return in staging, seed `vehicleType`/`vehicleName`/
`vehicleNumber`/`profilePhoto` on the seeded delivery partners.

### P2.3 — Seed offers/coupons
`GET /food/restaurant/offers` currently returns `[]`. Seed a few active coupons
so the coupon rail on the tracking/checkout screens has content (the app hides
the section when empty, so this is cosmetic but improves QA).

---

## Out of scope for the backend (handled/《noted》 in the app)
- Google Maps API key — configured on the client (`AndroidManifest.xml`).
- Razorpay sheet brand name — overridden client-side; still fix P0.4 for
  statements.
- The app already: seeds tracking from REST, drives live location from
  Socket.IO `location-update`, reads the RTDB polyline, polls every 10s as a
  socket fallback, and deep-links notifications to tracking.

## Summary checklist
- [ ] P0.1 Razorpay keys + webhook
- [ ] P0.2 Fee settings populated
- [ ] P0.3 verify-otp idempotent (no E11000)
- [ ] P0.4 Business name + hosted logo
- [ ] P1.1 Order populate: `profilePhoto` + vehicle fields + `totalDeliveries`
- [ ] P1.2 FCM push on every status transition
- [ ] P1.3 RTDB polyline always present post-pickup
- [ ] P1.4 Favorites endpoints
- [ ] P1.5 Real-time chat (REST + socket)
- [ ] P1.6 Tip endpoint
- [ ] P1.7 Invoice endpoint
- [ ] P2.x Seed/data hygiene

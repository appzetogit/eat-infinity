# Coupons & Offers — Flutter Implementation Guide

Everything the user app needs to list offers, let the customer apply a coupon in
the cart, and place an order with it. Verified against the backend code.

Companion doc: [FLUTTER_API_SPEC.md](FLUTTER_API_SPEC.md) (full API).

---

## 0. Basics

| | |
|---|---|
| Base URL | `https://amal.buytogetherindia.com/api/v1` |
| Media host | `https://amal.buytogetherindia.com` |
| Auth | `Authorization: Bearer <accessToken>` (user token from OTP login) |
| Envelope | `{ "success": true, "message": "…", "data": … }` |

Coupons are created by the admin in the web panel
(**Admin → Promotions Management → Restaurant Coupons & Offers**). The app only
reads and applies them — it never creates one.

**The golden rule: the server decides the discount.** Never compute a discount
on the phone and trust it. Show what `/food/orders/calculate` returns.

---

## 1. The three screens

```
Home "Hot Deals" tile ──► Offers screen (list of coupon cards)
                                │ tap card
                                ▼
                         Restaurant menu ──► Cart
                                              │ "Apply coupon"
                                              ▼
                                   Coupon picker sheet ──► /calculate with couponCode
                                              │
                                              ▼
                                  Place order (echo pricing) ──► payment
```

---

## 2. List offers — `GET /food/restaurant/offers`

Auth is **optional**. Send the token when the user is logged in: the server then
hides coupons they have used up, first-order coupons they no longer qualify for,
and shows customer-specific coupons issued to them.

| Query | When |
|---|---|
| *(none)* | Offers screen — every live coupon |
| `restaurantId` | Cart / menu — only coupons valid at this restaurant (global + ones naming it) |
| `subtotal` | Cart — drops coupons whose minimum order the cart doesn't reach |

Response `data`:

```json
{
  "allOffers": [
    {
      "id": "8662d35ff83ea793f0a91c88",
      "offerId": "8662d35ff83ea793f0a91c88",
      "couponCode": "WELCOME50",
      "title": "50% OFF",
      "discountType": "percentage",
      "discountValue": 50,
      "maxDiscount": 100,
      "minOrderValue": 199,
      "perUserLimit": 1,
      "customerScope": "first_time",
      "isFirstOrderOnly": false,
      "restaurantScope": "all",
      "restaurantId": null,
      "restaurantIds": [],
      "restaurantName": "All Restaurants",
      "restaurantSlug": null,
      "restaurantImage": null,
      "imageUrl": "/uploads/food/offers/1790595345668-5c67bbe97fb7be42.webp",
      "deliveryTime": null,
      "restaurantRating": 0,
      "endDate": "2026-12-31T23:59:59.999Z",
      "showInCart": true
    }
  ],
  "groupedByOffer": {}
}
```

Field notes:

- **`title`** is prebuilt (`"50% OFF"` or `"Flat ₹100 OFF"`). Render it as-is.
- **`discountType`**: `"percentage"` or `"flat_price"`.
- **`maxDiscount`**: cap for percentage coupons (`null` for flat).
- **`customerScope`**: `"all"`, `"first_time"` or `"specific"`.
- **`restaurantScope`**: `"all"` (works everywhere) or `"selected"` (only `restaurantIds`).
  For `"selected"`, `restaurantName`/`restaurantSlug`/`restaurantImage` describe one of them.
- **`imageUrl`**: the card image the admin uploaded, or `""` if none. **New.**
- **`endDate`**: ISO string or `null` (no expiry). A coupon ending today stays valid all day.
- **`groupedByOffer`**: always `{}` — ignore it.
- There is **no pagination**; the list is everything live.

### Card image — resolving the URL

`imageUrl` / `restaurantImage` are usually **relative** (`/uploads/...`). Prefix
the media host; leave absolute URLs alone. Fallback order:
`imageUrl` → `restaurantImage` → a local placeholder asset.

```dart
const mediaHost = 'https://amal.buytogetherindia.com';

String? resolveMedia(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final u = url.trim();
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  return '$mediaHost${u.startsWith('/') ? '' : '/'}$u';
}

String? offerCardImage(Offer o) => resolveMedia(o.imageUrl) ?? resolveMedia(o.restaurantImage);
```

Card aspect ratio in the web app is **2:1** — use the same so admin artwork isn't cropped oddly.

---

## 3. Apply a coupon — `POST /food/orders/calculate` (Bearer)

There is **no separate "validate coupon" endpoint**. You apply a coupon by
recalculating the cart with `couponCode` in the body:

```json
{
  "items": [
    { "itemId": "…", "name": "Paneer Tikka", "price": 240, "quantity": 2, "isVeg": true }
  ],
  "restaurantId": "…",
  "deliveryAddressId": "…",
  "zoneId": "…",
  "couponCode": "WELCOME50",
  "deliveryMode": "basic"
}
```

Relevant part of the response `data.pricing`:

```json
{
  "subtotal": 480,
  "discount": 100,
  "couponCode": "WELCOME50",
  "appliedCoupon": { "code": "WELCOME50", "discount": 100 },
  "tax": 19,
  "deliveryFee": 35,
  "platformFee": 5,
  "total": 439
}
```

### How to tell if it worked

**Check `appliedCoupon`, not `couponCode`.**

| `appliedCoupon` | Meaning | UI |
|---|---|---|
| `{ code, discount }` | Applied | Show "WELCOME50 applied — you saved ₹100" |
| `null` | Rejected (silently) | Show "This coupon isn't valid for this order", clear it |

A rejected coupon does **not** return an error — the request still succeeds,
`discount` is `0`, and `couponCode` is echoed back. The server doesn't say
*why*, so explain it from the offer data you already have (see §5).

A coupon is rejected when any of these fail:

1. inactive, or hidden from cart by the admin
2. before `startDate` / after `endDate`
3. `restaurantScope: "selected"` and this restaurant isn't in `restaurantIds`
4. `subtotal` < `minOrderValue`
5. global usage limit reached
6. this user reached `perUserLimit`
7. `customerScope: "specific"` and this user isn't on the list
8. first-order coupon (`first_time` or `isFirstOrderOnly`) and the user has ordered before

Codes are case-insensitive — the server upper-cases them. Uppercase in the UI too.

### Discount maths (for "you save ₹X" copy only — never for the bill)

- percentage: `floor(min(subtotal × value/100, maxDiscount))`
- flat: `floor(min(value, subtotal))`
- never more than the subtotal
- GST is charged on `subtotal − discount`

---

## 4. Place the order — `POST /food/orders` (Bearer)

Echo the **`pricing` object from the latest `/calculate`** — including
`couponCode`. The server recalculates everything from `pricing.couponCode` and
re-checks the coupon, so a stale or tampered discount can't get through.

```json
{
  "items": [ /* same items */ ],
  "restaurantId": "…",
  "address": { /* see FLUTTER_API_SPEC.md §7 */ },
  "pricing": { /* exactly what /calculate returned */ },
  "paymentMethod": "razorpay"
}
```

If the coupon became invalid between calculate and order (e.g. usage limit hit
by someone else), the order is simply priced without it. To avoid surprising
the user, **re-run `/calculate` right before "Place order"** and show the final
total from that response.

---

## 5. Cart logic (the part that's easy to get wrong)

1. **Recalculate on every cart change** (quantity, item, address, delivery mode)
   while a coupon is applied, passing the same `couponCode`. If `appliedCoupon`
   comes back `null`, remove the coupon and tell the user why
   (usually: subtotal dropped below `minOrderValue`).
2. **Picker sheet**: call `GET /food/restaurant/offers?restaurantId=<id>` (with
   token). Don't pass `subtotal` here — instead show below-minimum coupons
   greyed out with "Add ₹X more to use this", which is a better nudge.
3. **Manual entry**: let the user type a code too (customer-specific codes are
   shared privately). Apply it through `/calculate` exactly the same way.
4. **One coupon per order.** Applying a new one replaces the old.
5. **Removing**: recalculate without `couponCode`.
6. **Logged out**: coupons can be browsed, but applying needs the Bearer token
   (`/calculate` requires login). Prompt login on "Apply".

Explaining a rejection from the offer you already have:

```dart
String rejectionReason(Offer o, double subtotal, String restaurantId) {
  if (subtotal < o.minOrderValue) {
    return 'Add ₹${(o.minOrderValue - subtotal).ceil()} more to use ${o.couponCode}';
  }
  if (o.restaurantScope == 'selected' && !o.restaurantIds.contains(restaurantId)) {
    return '${o.couponCode} is not valid at this restaurant';
  }
  if (o.customerScope == 'first_time' || o.isFirstOrderOnly) {
    return '${o.couponCode} is only for your first order';
  }
  return '${o.couponCode} is not valid for this order';
}
```

---

## 6. Dart reference code

### Model

```dart
class Offer {
  final String id;
  final String couponCode;
  final String title;
  final String discountType; // percentage | flat_price
  final double discountValue;
  final double? maxDiscount;
  final double minOrderValue;
  final String customerScope; // all | first_time | specific
  final bool isFirstOrderOnly;
  final String restaurantScope; // all | selected
  final List<String> restaurantIds;
  final String restaurantName;
  final String? restaurantSlug;
  final String? restaurantImage;
  final String imageUrl;
  final DateTime? endDate;

  Offer.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        couponCode = (j['couponCode'] as String).toUpperCase(),
        title = j['title'] as String? ?? '',
        discountType = j['discountType'] as String? ?? 'percentage',
        discountValue = (j['discountValue'] as num?)?.toDouble() ?? 0,
        maxDiscount = (j['maxDiscount'] as num?)?.toDouble(),
        minOrderValue = (j['minOrderValue'] as num?)?.toDouble() ?? 0,
        customerScope = j['customerScope'] as String? ?? 'all',
        isFirstOrderOnly = j['isFirstOrderOnly'] as bool? ?? false,
        restaurantScope = j['restaurantScope'] as String? ?? 'all',
        restaurantIds = (j['restaurantIds'] as List? ?? []).cast<String>(),
        restaurantName = j['restaurantName'] as String? ?? 'All Restaurants',
        restaurantSlug = j['restaurantSlug'] as String?,
        restaurantImage = j['restaurantImage'] as String?,
        imageUrl = j['imageUrl'] as String? ?? '',
        endDate = j['endDate'] == null ? null : DateTime.parse(j['endDate'] as String).toLocal();
}

class AppliedCoupon {
  final String code;
  final double discount;
  AppliedCoupon.fromJson(Map<String, dynamic> j)
      : code = j['code'] as String,
        discount = (j['discount'] as num).toDouble();
}
```

### Service (Dio)

```dart
class CouponService {
  CouponService(this._dio); // baseUrl = https://amal.buytogetherindia.com/api/v1
  final Dio _dio;

  Future<List<Offer>> listOffers({String? restaurantId, double? subtotal}) async {
    final res = await _dio.get('/food/restaurant/offers', queryParameters: {
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (subtotal != null) 'subtotal': subtotal,
    });
    final list = (res.data['data']['allOffers'] as List?) ?? [];
    return list.map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Returns the full pricing map; check pricing['appliedCoupon'].
  Future<Map<String, dynamic>> calculate(Map<String, dynamic> cartBody, {String? couponCode}) async {
    final res = await _dio.post('/food/orders/calculate', data: {
      ...cartBody,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode.trim().toUpperCase(),
    });
    return res.data['data'] as Map<String, dynamic>;
  }
}
```

### Applying from the cart

```dart
Future<void> applyCoupon(String code) async {
  final data = await couponService.calculate(cartBody, couponCode: code);
  final pricing = data['pricing'] as Map<String, dynamic>;
  final applied = pricing['appliedCoupon'];

  if (applied == null) {
    state = state.copyWith(couponCode: null, pricing: pricing);
    showSnack(rejectionReasonFor(code));
    return;
  }
  final c = AppliedCoupon.fromJson(applied as Map<String, dynamic>);
  state = state.copyWith(couponCode: c.code, pricing: pricing);
  showSnack('${c.code} applied — you saved ₹${c.discount.toStringAsFixed(0)}');
}
```

---

## 7. Offers screen checklist

- [ ] Card: image (2:1), `title` badge, `couponCode` with a copy button, `restaurantName`, "Valid till …" from `endDate`, "Min order ₹X" when `minOrderValue > 0`
- [ ] Tap a `selected` coupon → open that restaurant (`restaurantSlug`); tap an `all` coupon → copy code / go home
- [ ] Empty state: "No offers right now" (the list can legitimately be empty)
- [ ] Pull-to-refresh; no client cache needed
- [ ] Send the token when logged in so the list is personalised

## 8. Cart checklist

- [ ] "Apply coupon" row → picker sheet (`?restaurantId=`), plus a text field for manual codes
- [ ] Applied state shows code, savings, and a remove (×) button
- [ ] Bill shows a `Coupon discount  −₹X` row from `pricing.discount`
- [ ] Every cart change recalculates with the current code; auto-remove + message if it drops
- [ ] Re-calculate right before "Place order"; send that `pricing` unchanged

---

## 9. Testing

The test server uses a fixed OTP: log in with **any phone number and OTP `1234`**.

Create test coupons in the admin panel
(`https://amal.buytogetherindia.com/admin/food/coupons`). Suggested cases:

| Coupon | Setup | Expect |
|---|---|---|
| `FLAT50` | flat ₹50, all restaurants | applies anywhere |
| `PIZZA20` | 20%, max ₹80, only Palasia Pizza Co. | applies only in that restaurant's cart |
| `MIN300` | flat ₹60, min order ₹300 | rejected under ₹300; drops off when cart falls below |
| `FIRST100` | flat ₹100, first-time customers | works for a new phone number, not after one order |
| `ONCE` | flat ₹30, per-user limit 1 | disappears from the list once one order with it is paid (usage is counted at payment, not at "Place order") |
| with image | any coupon, upload an image | card shows it; without image, restaurant photo |

Seeded Indore restaurants are live on the test server, so real carts can be
built against them.

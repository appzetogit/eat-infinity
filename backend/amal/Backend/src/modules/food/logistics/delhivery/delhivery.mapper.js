/**
 * Pure translation between our orders and Delhivery Local payloads.
 *
 * No I/O here, so every rule (payload shape, state ordering, which order
 * milestones a jump in state crosses) is unit-tested against the samples in
 * the Delhivery contract without a network or a database.
 */

/** Cancellation reasons Delhivery accepts, verbatim from the contract. */
export const CANCEL_REASONS = Object.freeze({
    NO_DRIVER: 'taking too long to assign a driver',
    NOT_REQUIRED: 'service is no longer required',
    WRONG_VEHICLE: 'requested wrong vehicle',
    WRONG_ADDRESS: 'requested wrong pickup or destination',
    PICKUP_TAT_BREACHED: 'pickup tat breached',
    FRAUD: 'fraudulent rider behaviour',
});

export const VEHICLE_MODES = Object.freeze(['2-wheeler', '3-wheeler', 'mini-3w', 'tata-ace', '8ft-pickup']);

/**
 * Forward order of fulfilment states. Multi-stop states (at_stopN) are never
 * produced for food orders, which are single drop.
 */
export const FULFILMENT_RANK = Object.freeze({
    pending: 0,
    searching_for_agent: 1,
    agent_assigned: 2,
    at_pickup: 3,
    out_for_delivery: 4,
    at_delivery: 5,
    order_delivered: 6,
    cancelled: 9,
});

export const rankOf = (fulfilmentStatus) => FULFILMENT_RANK[String(fulfilmentStatus || '').toLowerCase()] ?? -1;

export const isTerminalFulfilment = (s) => ['order_delivered', 'cancelled'].includes(String(s || '').toLowerCase());

/** Rider has the food (or is past it): cancelling is no longer safe. */
export const isPastPickup = (s) => rankOf(s) >= FULFILMENT_RANK.out_for_delivery && rankOf(s) < FULFILMENT_RANK.cancelled;

/** Still waiting for Delhivery to find a rider. */
export const isAwaitingRider = (s) => rankOf(s) <= FULFILMENT_RANK.searching_for_agent;

const str = (v) => (v === undefined || v === null ? '' : String(v).trim());
const coord = (v) => (Number.isFinite(Number(v)) ? String(Number(v)) : undefined);

/** Indian numbers → { countryCode: '+91', phoneNumber: last 10 digits }. */
export function splitPhone(raw) {
    const digits = str(raw).replace(/\D/g, '');
    return { countryCode: '+91', phoneNumber: digits.length > 10 ? digits.slice(-10) : digits };
}

/** Delhivery reports TATs as strings in a unit it labels "ms" while the values
 *  read as seconds ("900" for a 15-minute pickup). Accept both. */
export function tatToSeconds(value) {
    const n = Number(value);
    if (!Number.isFinite(n) || n <= 0) return null;
    return n > 100_000 ? Math.round(n / 1000) : Math.round(n);
}

const geo = (lat, lng) => {
    const latitude = coord(lat);
    const longitude = coord(lng);
    return latitude && longitude ? { latitude, longitude } : undefined;
};

const restaurantAddress = (r = {}) => ({
    address1: str(r.addressLine1) || str(r.formattedAddress) || str(r.area) || str(r.restaurantName) || 'Restaurant',
    address2: str(r.area) || undefined,
    city: str(r.city) || undefined,
    state: str(r.state) || undefined,
    pinCode: str(r.pincode) || undefined,
    geoLocation: geo(r.latitude, r.longitude),
});

const customerAddress = (o = {}) => ({
    address1: str(o.addrStreet) || str(o.addrAdditionalDetails) || 'Customer address',
    address2: str(o.addrAdditionalDetails) || undefined,
    city: str(o.addrCity) || undefined,
    state: str(o.addrState) || undefined,
    pinCode: str(o.addrZipCode) || undefined,
    geoLocation: geo(o.addrLat, o.addrLng),
});

/** Drop the undefined keys so the payload matches the contract exactly. */
const compact = (obj) => JSON.parse(JSON.stringify(obj));

export function buildQuotePayload({ restaurant, order, customerName, customerPhone }) {
    const phone = splitPhone(customerPhone);
    return compact({
        pickupDetails: restaurantAddress(restaurant),
        dropDetails: customerAddress(order),
        customerDetails: customerName || phone.phoneNumber
            ? { customerName: str(customerName) || 'Customer', ...phone }
            : undefined,
    });
}

/**
 * The fare / TAT for the vehicle we asked for, out of a quote response.
 * Returns null when Delhivery did not offer that vehicle.
 */
export function pickQuote(data, vehicleMode = '2-wheeler') {
    const vehicles = Array.isArray(data?.vehicles) ? data.vehicles : [];
    const v = vehicles.find((x) => str(x?.type).toLowerCase() === vehicleMode.toLowerCase());
    if (!v) return null;
    const distance = Number(v.pickupDropDistance?.distance);
    return {
        vehicleMode: v.type,
        fare: Number(v.fare?.amount) || 0,
        currency: v.fare?.currency || 'INR',
        pickupTatSec: tatToSeconds(v.tat?.pickupTat),
        deliveryTatSec: tatToSeconds(v.tat?.deliveryTat),
        distanceKm: Number.isFinite(distance)
            ? (str(v.pickupDropDistance?.unit).toLowerCase() === 'km' ? distance : distance / 1000)
            : null,
        capacityKg: Number(v.capacity?.value) || null,
    };
}

/**
 * Create-order payload for one food order.
 *
 * Both OTPs are CLIENT_GENERATED: the drop OTP is the code the customer already
 * sees in our app, so the Delhivery rider asks for the same number our own
 * riders do.
 */
export function buildCreatePayload({
    order,
    restaurant,
    items = [],
    customerName,
    customerPhone,
    vehicleMode = '2-wheeler',
    readyToShip = true,
    dropOtp,
    pickupOtp,
    webhookUrl,
    webhookApiKey,
}) {
    const drop = splitPhone(customerPhone);
    const pickup = splitPhone(restaurant?.primaryContactNumber || restaurant?.ownerPhone);
    const subtotal = Number(order?.subtotal);
    const value = Number.isFinite(subtotal) && subtotal > 0 ? subtotal : 1;

    const payload = {
        clientReferenceOrderId: str(order?.order_id) || str(order?.id),
        serviceType: 'local',
        vehicleMode,
        paymentType: 'PrePaid',
        metadata: { readyToShip: Boolean(readyToShip) },
        pickupDetails: {
            contactDetails: {
                shipperName: str(restaurant?.restaurantName) || 'Restaurant',
                ...pickup,
            },
            ...restaurantAddress(restaurant),
            ...(pickupOtp ? { otpValue: String(pickupOtp) } : {}),
        },
        dropDetails: {
            contactDetails: {
                consigneeName: str(customerName) || str(order?.addrFullName) || str(order?.addrName) || 'Customer',
                ...drop,
            },
            ...customerAddress(order),
            ...(dropOtp ? { otpValue: String(dropOtp) } : {}),
        },
        pickupInstructions: `Food order ${str(order?.order_id) || ''}. Collect from the counter.`.trim(),
        deliveryInstructions: str(order?.deliveryInstructions) || undefined,
        itemDetails: {
            description: items.length
                ? items.map((it) => `${Number(it.quantity) || 1} x ${str(it.name) || 'Item'}`)
                : ['Food order'],
            value,
        },
        pickupOtpConfig: pickupOtp
            ? { otpEnable: true, otpType: 'CLIENT_GENERATED', otpValue: String(pickupOtp) }
            : { otpEnable: false },
        dropOtpConfig: dropOtp
            ? { otpEnable: true, otpType: 'CLIENT_GENERATED', otpValue: String(dropOtp) }
            : { otpEnable: false },
    };

    if (webhookUrl) {
        payload.webhook = { url: webhookUrl, ...(webhookApiKey ? { xApiKey: webhookApiKey } : {}) };
    }
    return compact(payload);
}

/** Webhooks and Track responses come both wrapped ({ data: {...} }) and bare. */
export function unwrap(body) {
    if (body && typeof body === 'object' && body.data && typeof body.data === 'object' && body.data.orderId) {
        return body.data;
    }
    return body && typeof body === 'object' ? body : {};
}

/** One shape for a Delhivery order, whichever endpoint it came from. */
export function normalizeTracking(body) {
    const d = unwrap(body);
    const partner = d.partnerInfo && typeof d.partnerInfo === 'object' ? d.partnerInfo : null;
    const mobile = partner?.mobile?.mobileNumber ? str(partner.mobile.mobileNumber) : '';
    const lat = Number(partner?.location?.lat);
    const lng = Number(partner?.location?.long ?? partner?.location?.lng);
    const fare = d.fareDetails?.finalFareDetails?.amount ?? d.fareDetails?.estimatedFareDetails?.amount;
    return {
        providerOrderId: str(d.orderId) || null,
        clientReferenceOrderId: str(d.clientReferenceOrderId) || null,
        status: str(d.status).toLowerCase() || null,
        fulfilmentStatus: str(d.fulfilmentStatus).toLowerCase() || null,
        nextDestination: d.nextDestination ? str(d.nextDestination) : null,
        rider: partner
            ? {
                name: str(partner.name) || null,
                phone: mobile ? `+${str(partner.mobile.countryCode || '91').replace(/^\+/, '')}${mobile}` : null,
                vehicleNumber: str(partner.vehicleNumber) || null,
                vehicleType: str(partner.vehicleType) || null,
                lat: Number.isFinite(lat) ? lat : null,
                lng: Number.isFinite(lng) ? lng : null,
            }
            : null,
        fare: Number.isFinite(Number(fare)) ? Number(fare) : null,
        trackingUrl: str(d.trackingUrl) || null,
        cancellationReason: str(d.cancellationReason) || null,
        timings: d.orderTimings || null,
    };
}

/**
 * Order milestones crossed when Delhivery moves from `from` to `to`.
 *
 * Webhooks can be skipped or arrive late, and at_pickup / at_delivery are sent
 * as webhooks only (the poller never sees them). So a jump straight from
 * agent_assigned to out_for_delivery must still record that the rider reached
 * the restaurant, in order.
 */
export function milestonesBetween(from, to) {
    const a = rankOf(from);
    const b = rankOf(to);
    if (b <= a || b >= FULFILMENT_RANK.cancelled) return [];
    const steps = [];
    if (a < FULFILMENT_RANK.at_pickup && b >= FULFILMENT_RANK.at_pickup) steps.push('reached_pickup');
    if (a < FULFILMENT_RANK.out_for_delivery && b >= FULFILMENT_RANK.out_for_delivery) steps.push('picked_up');
    if (a < FULFILMENT_RANK.at_delivery && b >= FULFILMENT_RANK.at_delivery) steps.push('reached_drop');
    if (a < FULFILMENT_RANK.order_delivered && b >= FULFILMENT_RANK.order_delivered) steps.push('delivered');
    return steps;
}

/** Customer-facing words for a fulfilment state. */
export function describeFulfilment(s) {
    switch (String(s || '').toLowerCase()) {
        case 'pending':
        case 'searching_for_agent':
            return 'Finding a delivery partner';
        case 'agent_assigned':
            return 'Delivery partner on the way to the restaurant';
        case 'at_pickup':
            return 'Delivery partner at the restaurant';
        case 'out_for_delivery':
            return 'On the way to you';
        case 'at_delivery':
            return 'Delivery partner has arrived';
        case 'order_delivered':
            return 'Delivered';
        case 'cancelled':
            return 'Delivery cancelled';
        default:
            return '';
    }
}

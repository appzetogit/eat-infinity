import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
    buildCreatePayload,
    buildQuotePayload,
    isAwaitingRider,
    isPastPickup,
    milestonesBetween,
    normalizeTracking,
    pickQuote,
    rankOf,
    splitPhone,
    tatToSeconds,
    unwrap,
} from './delhivery.mapper.js';

// Samples lifted from the Delhivery Direct Intracity APIs contract V6.
const AGENT_ASSIGNED = {
    data: {
        orderId: 'CRN1830008718JJ',
        status: 'assigned',
        fulfilmentStatus: 'agent_assigned',
        nextDestination: 'pickup',
        partnerInfo: {
            name: 'Utkarsh Rider',
            vehicleNumber: 'DL98349',
            vehicleType: 'tata-ace',
            mobile: { countryCode: '91', mobileNumber: '' },
            location: { lat: 28.455062, long: 77.070153 },
        },
        fareDetails: { estimatedFareDetails: { currency: 'INR', amount: 427 } },
        clientReferenceOrderId: 'Webbing-1dkknfdDHSbbn3',
        trackingUrl: 'https://v3.delhivery.com/local?order_id=CRN1830008718JJ',
    },
    success: true,
};

// The contract's at_delivery / order_delivered samples are NOT wrapped in data.
const AT_DELIVERY_BARE = {
    orderId: 'CRN1957000892AO',
    status: 'inProgress',
    fulfilmentStatus: 'at_delivery',
    nextDestination: 'drop',
    partnerInfo: {
        name: 'Utkarsh Rider',
        vehicleNumber: 'DL98349',
        vehicleType: 'tata-ace',
        mobile: { countryCode: '91', mobileNumber: '9718205080' },
        location: { lat: 28.455067, long: 77.070147 },
    },
    trackingUrl: 'https://v3.delhivery.com/local?order_id=CRN1957000892AO',
};

const CANCELLED = {
    data: {
        orderId: 'CRN19260039821F',
        status: 'cancelled',
        fulfilmentStatus: 'cancelled',
        partnerInfo: { name: 'Utkarsh Rider', mobile: { countryCode: '91', mobileNumber: '' }, location: null },
        cancellationReason: 'taking too long to assign a driver',
    },
    success: true,
};

const QUOTE = {
    vehicles: [
        {
            type: '2-wheeler',
            fare: { currency: 'INR', amount: 158.0 },
            capacity: { value: 20.0, unit: 'kg' },
            tat: { deliveryTat: '1800', pickupTat: '900', unit: 'ms' },
            pickupDropDistance: { distance: 2300, unit: 'm' },
        },
    ],
    service_type: 'local',
};

test('normalizeTracking reads a wrapped Track/webhook payload', () => {
    const t = normalizeTracking(AGENT_ASSIGNED);
    assert.equal(t.providerOrderId, 'CRN1830008718JJ');
    assert.equal(t.fulfilmentStatus, 'agent_assigned');
    assert.equal(t.rider.name, 'Utkarsh Rider');
    assert.equal(t.rider.phone, null, 'empty mobile must not become "+91"');
    assert.equal(t.rider.lat, 28.455062);
    assert.equal(t.rider.lng, 77.070153);
    assert.equal(t.fare, 427);
    assert.match(t.trackingUrl, /CRN1830008718JJ/);
});

test('normalizeTracking reads the bare (unwrapped) samples too', () => {
    const t = normalizeTracking(AT_DELIVERY_BARE);
    assert.equal(t.providerOrderId, 'CRN1957000892AO');
    assert.equal(t.fulfilmentStatus, 'at_delivery');
    assert.equal(t.rider.phone, '+919718205080');
    assert.equal(unwrap(AT_DELIVERY_BARE), AT_DELIVERY_BARE);
});

test('a cancellation carries its reason and a null location', () => {
    const t = normalizeTracking(CANCELLED);
    assert.equal(t.fulfilmentStatus, 'cancelled');
    assert.equal(t.cancellationReason, 'taking too long to assign a driver');
    assert.equal(t.rider.lat, null);
});

test('milestones are forward-only and fill in skipped webhook-only states', () => {
    assert.deepEqual(milestonesBetween('agent_assigned', 'out_for_delivery'), ['reached_pickup', 'picked_up']);
    assert.deepEqual(milestonesBetween('searching_for_agent', 'order_delivered'), [
        'reached_pickup', 'picked_up', 'reached_drop', 'delivered',
    ]);
    assert.deepEqual(milestonesBetween('at_delivery', 'out_for_delivery'), [], 'late event is ignored');
    assert.deepEqual(milestonesBetween('at_pickup', 'at_pickup'), [], 'duplicate is ignored');
    assert.deepEqual(milestonesBetween('agent_assigned', 'cancelled'), [], 'cancel is handled separately');
});

test('state helpers', () => {
    assert.ok(rankOf('out_for_delivery') > rankOf('at_pickup'));
    assert.equal(rankOf('something_new'), -1);
    assert.ok(isAwaitingRider('searching_for_agent'));
    assert.ok(!isAwaitingRider('agent_assigned'));
    assert.ok(isPastPickup('out_for_delivery'));
    assert.ok(!isPastPickup('at_pickup'));
    assert.ok(!isPastPickup('cancelled'));
});

test('pickQuote picks the requested vehicle and converts units', () => {
    const q = pickQuote(QUOTE, '2-wheeler');
    assert.equal(q.fare, 158);
    assert.equal(q.pickupTatSec, 900);
    assert.equal(q.deliveryTatSec, 1800);
    assert.equal(q.distanceKm, 2.3);
    assert.equal(pickQuote(QUOTE, 'tata-ace'), null);
});

test('tatToSeconds accepts seconds or milliseconds', () => {
    assert.equal(tatToSeconds('900'), 900);
    assert.equal(tatToSeconds(900000), 900);
    assert.equal(tatToSeconds(null), null);
});

test('splitPhone keeps the last ten digits', () => {
    assert.deepEqual(splitPhone('+91 98765-43210'), { countryCode: '+91', phoneNumber: '9876543210' });
    assert.deepEqual(splitPhone('9876543210'), { countryCode: '+91', phoneNumber: '9876543210' });
});

const ORDER = {
    id: 'ord1',
    order_id: 'FOD-1234',
    subtotal: 480,
    addrFullName: 'Ravi Kumar',
    addrPhone: '9876543210',
    addrStreet: '12 CG Road',
    addrCity: 'Ahmedabad',
    addrState: 'Gujarat',
    addrZipCode: '380009',
    addrLat: 23.0258,
    addrLng: 72.5604,
    deliveryInstructions: 'Ring the bell',
};
const RESTAURANT = {
    restaurantName: 'Test Kitchen',
    primaryContactNumber: '9000000101',
    latitude: 23.0225,
    longitude: 72.5714,
    addressLine1: 'Navrangpura',
    city: 'Ahmedabad',
    state: 'Gujarat',
    pincode: '380009',
};

test('create payload: prepaid, client OTPs, items, webhook', () => {
    const p = buildCreatePayload({
        order: ORDER,
        restaurant: RESTAURANT,
        items: [{ name: 'Paneer Tikka', quantity: 2 }],
        customerName: 'Ravi Kumar',
        customerPhone: '+919876543210',
        readyToShip: false,
        dropOtp: '4321',
        webhookUrl: 'https://example.test/api/v1/webhooks/delhivery',
        webhookApiKey: 'k',
    });
    assert.equal(p.clientReferenceOrderId, 'FOD-1234');
    assert.equal(p.paymentType, 'PrePaid');
    assert.equal(p.vehicleMode, '2-wheeler');
    assert.equal(p.metadata.readyToShip, false);
    assert.equal(p.dropDetails.contactDetails.phoneNumber, '9876543210');
    assert.equal(p.dropDetails.geoLocation.latitude, '23.0258');
    assert.equal(p.pickupDetails.contactDetails.shipperName, 'Test Kitchen');
    assert.deepEqual(p.dropOtpConfig, { otpEnable: true, otpType: 'CLIENT_GENERATED', otpValue: '4321' });
    assert.equal(p.dropDetails.otpValue, '4321');
    assert.deepEqual(p.pickupOtpConfig, { otpEnable: false });
    assert.deepEqual(p.itemDetails, { description: ['2 x Paneer Tikka'], value: 480 });
    assert.deepEqual(p.webhook, { url: 'https://example.test/api/v1/webhooks/delhivery', xApiKey: 'k' });
    assert.ok(!('undefined' in p), 'no undefined keys leak through');
});

test('quote payload carries both coordinates', () => {
    const p = buildQuotePayload({ restaurant: RESTAURANT, order: ORDER, customerName: 'Ravi', customerPhone: '9876543210' });
    assert.equal(p.pickupDetails.geoLocation.longitude, '72.5714');
    assert.equal(p.dropDetails.geoLocation.latitude, '23.0258');
    assert.equal(p.customerDetails.phoneNumber, '9876543210');
});

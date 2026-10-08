import { prisma } from '../../../../config/prisma.js';
import { config } from '../../../../config/env.js';
import { logger } from '../../../../utils/logger.js';
import { ValidationError, NotFoundError } from '../../../../core/auth/errors.js';
import { getIO, rooms } from '../../../../config/socket.js';
import { parseGeoPoint } from '../../shared/geo.utils.js';
import { toOrder, orderInclude } from '../../orders/order.mapper.js';
import {
    emitDeliveryDropOtpToUser,
    enqueueOrderEvent,
    generateFourDigitDeliveryOtp,
    isStatusAdvance,
    notifyOwnersSafely,
    pushStatusHistory,
    TERMINAL_ORDER_STATUSES,
} from '../../orders/services/order.helpers.js';
import { delhiveryApi, DelhiveryError, isDelhiveryConfigured, delhiveryBaseUrl, getAccessToken } from './delhivery.client.js';
import {
    CANCEL_REASONS,
    buildCreatePayload,
    buildQuotePayload,
    describeFulfilment,
    isAwaitingRider,
    isPastPickup,
    milestonesBetween,
    normalizeTracking,
    pickQuote,
    rankOf,
} from './delhivery.mapper.js';

/**
 * Delhivery Local as a delivery provider, switched on per zone.
 *
 * The seam is tryAutoAssign: every dispatch — the restaurant accepting, a rider
 * rejecting, the watchdog — goes through it, and routeOrderToProvider decides
 * there whether an order is ours to dispatch or Delhivery's. A Delhivery order
 * is marked dispatched-and-accepted on our side, which keeps the watchdog and
 * the stalled-order expiry (both of which only look at orders with no accepted
 * rider) away from it; from then on its state comes from Delhivery's webhooks,
 * with a poller in the scheduler as the backstop.
 *
 * Only prepaid orders are sent. A Delhivery rider can neither collect cash nor
 * show our pay-at-door QR, so a Delhivery-only zone refuses those at checkout.
 */

/** Delhivery attempts per order before an admin has to step in. */
const MAX_ATTEMPTS = 2;
/** Marks the attempt after which an order belongs to our own riders for good. */
export const HANDOFF_TO_OWN = 'handed_to_own_fleet';

const DISPATCHABLE = ['confirmed', 'preparing', 'ready_for_pickup'];
const PREPAID_METHODS = ['razorpay', 'wallet', 'card'];

const RESTAURANT_SELECT = {
    id: true, restaurantName: true, zoneId: true, ownerPhone: true, primaryContactNumber: true,
    latitude: true, longitude: true, addressLine1: true, area: true, city: true, state: true,
    pincode: true, formattedAddress: true,
};

// ── zone config ──────────────────────────────────────────────────────────────

const CONFIG_TTL_MS = 60 * 1000;
const configCache = new Map();

export const DEFAULT_ZONE_CONFIG = Object.freeze({
    mode: 'own',
    isEnabled: false,
    vehicleMode: '2-wheeler',
    assignTimeoutMin: 10,
    onNoRider: 'notify_admin',
    confirmPolicy: 'prep_aligned',
    defaultPrepMinutes: 15,
    maxFare: null,
    checkServiceability: true,
    pickupOtpEnabled: false,
});

export async function getZoneDeliveryConfig(zoneId) {
    if (!zoneId) return null;
    const key = String(zoneId);
    const hit = configCache.get(key);
    if (hit && hit.at > Date.now() - CONFIG_TTL_MS) return hit.value;
    const value = await prisma.foodZoneDeliveryConfig.findUnique({ where: { zoneId: key } });
    configCache.set(key, { at: Date.now(), value });
    return value;
}

export const invalidateZoneConfig = (zoneId) => configCache.delete(String(zoneId));

/** The zone actually sends orders to Delhivery right now (first or as fallback). */
const usesDelhivery = (cfg) =>
    Boolean(cfg && cfg.isEnabled && cfg.mode !== 'own' && isDelhiveryConfigured());

const isPrepaid = (row) =>
    String(row.paymentStatus || '') === 'paid' || PREPAID_METHODS.includes(String(row.paymentMethod || ''));

export const webhookUrl = () =>
    config.delhivery.publicBaseUrl ? `${config.delhivery.publicBaseUrl}/api/v1/webhooks/delhivery` : null;

// ── realtime + notifications ─────────────────────────────────────────────────

function emitOrderUpdate(order) {
    try {
        const io = getIO();
        if (!io) return;
        const payload = {
            orderMongoId: order.id,
            orderId: order.id,
            orderStatus: order.orderStatus,
            deliveryState: order.deliveryState,
            deliveryProvider: 'delhivery',
        };
        io.to(rooms.restaurant(order.restaurantId?.id ?? order.restaurantId)).emit('order_status_update', payload);
        io.to(rooms.user(order.userId?.id ?? order.userId)).emit('order_status_update', payload);
        io.to(rooms.admin()).emit('order_status_update', payload);
    } catch (err) {
        logger.warn(`[delhivery] emit failed: ${err?.message || err}`);
    }
}

function emitRiderLocation(row, lat, lng) {
    try {
        const io = getIO();
        if (!io) return;
        const payload = {
            orderId: row.id,
            deliveryPartnerId: 'delhivery',
            lat, lng, boy_lat: lat, boy_lng: lng, riderLocation: [lat, lng],
            heading: null, speed: null, accuracy: null,
            timestamp: Date.now(),
        };
        io.to(rooms.tracking(row.id)).emit('location-update', payload);
        io.to(rooms.user(row.userId)).emit('location-update', payload);
        io.to(rooms.restaurant(row.restaurantId)).emit('location-update', payload);
    } catch (err) {
        logger.warn(`[delhivery] location emit failed: ${err?.message || err}`);
    }
}

async function alertAdmin(title, body, data = {}) {
    logger.warn(`[delhivery] ADMIN ALERT: ${title} — ${body}`);
    try {
        await notifyOwnersSafely([{ ownerType: 'ADMIN', ownerId: 'GLOBAL' }], {
            title,
            body,
            data: { type: 'admin_alert_delivery_provider', ...data },
        });
    } catch (err) {
        logger.warn(`[delhivery] admin alert failed: ${err?.message || err}`);
    }
}

/** `row` must be a raw order row (string userId / restaurantId), not toOrder output. */
const notifyCustomerAndRestaurant = (row, title, body) =>
    notifyOwnersSafely(
        [
            { ownerType: 'USER', ownerId: row.userId },
            { ownerType: 'RESTAURANT', ownerId: row.restaurantId },
        ],
        {
            title,
            body,
            data: { type: 'order_status_update', orderId: row.id, orderMongoId: row.id, orderStatus: row.orderStatus },
        },
    ).catch(() => {});

// ── quote / serviceability ───────────────────────────────────────────────────

const quoteCache = new Map();
const QUOTE_TTL_MS = 5 * 60 * 1000;

async function quoteFor(restaurant, orderLike, vehicleMode, { customerName, customerPhone } = {}) {
    const payload = buildQuotePayload({ restaurant, order: orderLike, customerName, customerPhone });
    const data = await delhiveryApi.quote(payload);
    const q = pickQuote(data, vehicleMode);
    if (!q) throw new DelhiveryError(`Delhivery has no ${vehicleMode} for this trip`, { code: 424 });
    return { quote: q, vehicles: data?.vehicles || [] };
}

/**
 * Called from pricing: refuse a cart Delhivery cannot deliver before the
 * customer pays. Only a definite "not serviceable" blocks; a timeout or outage
 * does not, so a Delhivery blip never stops people ordering.
 */
export async function assertDeliverableByZoneProvider(restaurant, deliveryAddress) {
    if (!restaurant?.zoneId) return;
    const cfg = await getZoneDeliveryConfig(restaurant.zoneId);
    if (!usesDelhivery(cfg) || !cfg.checkServiceability || cfg.mode === 'own_then_delhivery') return;

    const drop = parseGeoPoint(deliveryAddress);
    const pickupLat = Number(restaurant.latitude);
    const pickupLng = Number(restaurant.longitude);
    if (!drop || !Number.isFinite(pickupLat) || !Number.isFinite(pickupLng)) return;

    const key = `${restaurant.id}:${drop.lat.toFixed(3)}:${drop.lng.toFixed(3)}:${cfg.vehicleMode}`;
    const cached = quoteCache.get(key);
    if (cached && cached.at > Date.now() - QUOTE_TTL_MS) {
        if (cached.notServiceable) throw notServiceableError();
        return;
    }

    try {
        await quoteFor(
            { latitude: pickupLat, longitude: pickupLng, restaurantName: restaurant.restaurantName },
            { addrLat: drop.lat, addrLng: drop.lng },
            cfg.vehicleMode,
        );
        quoteCache.set(key, { at: Date.now(), notServiceable: false });
    } catch (err) {
        if (err instanceof DelhiveryError && err.isNotServiceable) {
            quoteCache.set(key, { at: Date.now(), notServiceable: true });
            // Delhivery-first zones with our own fleet as backup can still deliver.
            if (cfg.mode === 'delhivery_then_own' || cfg.onNoRider === 'fallback_own') return;
            throw notServiceableError();
        }
        logger.warn(`[delhivery] serviceability check skipped: ${err?.message || err}`);
    }
}

const notServiceableError = () =>
    new ValidationError("Delivery isn't available to this address yet. Please choose another address.");

/**
 * Called when an order is placed: in a zone delivered only by Delhivery, a
 * cash or pay-at-door order would have nobody to collect the money.
 */
export async function assertPaymentMethodAllowedForZone(zoneId, paymentMethod) {
    if (!zoneId) return;
    const method = String(paymentMethod || '').toLowerCase();
    if (!['cash', 'razorpay_qr'].includes(method)) return;
    const cfg = await getZoneDeliveryConfig(zoneId);
    if (usesDelhivery(cfg) && cfg.mode === 'delhivery' && cfg.onNoRider !== 'fallback_own') {
        throw new ValidationError("Pay online to order in this area. Cash and pay-on-delivery aren't available here yet.");
    }
}

// ── routing (called from tryAutoAssign) ──────────────────────────────────────

/**
 * Decide whether Delhivery takes this order. Returns { handled: true } when the
 * order is (or stays) with Delhivery, or an admin has to act; { handled: false }
 * to let our own rider dispatch run as before.
 */
export async function routeOrderToProvider(orderId) {
    const row = await prisma.foodOrder.findUnique({
        where: { id: String(orderId) },
        select: {
            id: true, orderStatus: true, deliveryProvider: true, paymentMethod: true, paymentStatus: true,
            restaurant: { select: { zoneId: true } },
        },
    });
    if (!row) return { handled: false };
    if (row.deliveryProvider === 'delhivery') return { handled: true, reason: 'with_delhivery' };

    const cfg = await getZoneDeliveryConfig(row.restaurant?.zoneId);
    if (!usesDelhivery(cfg) || cfg.mode === 'own_then_delhivery') return { handled: false };
    if (!DISPATCHABLE.includes(row.orderStatus)) return { handled: false };
    if (!isPrepaid(row)) return { handled: false, reason: 'not_prepaid' };

    const attempts = await prisma.foodDeliveryShipment.findMany({
        where: { orderId: row.id },
        select: { active: true, failureReason: true },
    });
    if (attempts.some((a) => a.active)) return { handled: true, reason: 'with_delhivery' };
    if (attempts.some((a) => a.failureReason === HANDOFF_TO_OWN)) return { handled: false };
    if (attempts.length >= MAX_ATTEMPTS) return { handled: true, reason: 'needs_admin' };

    try {
        const shipment = await startShipment(row.id, { cfg });
        return { handled: true, shipment };
    } catch (err) {
        // Another dispatch of this same order holds the lock: it is in hand.
        if (err?.code === 'DISPATCH_LOCKED') return { handled: true, reason: 'in_progress' };
        logger.warn(`[delhivery] could not send ${row.id} to Delhivery: ${err?.message || err}`);
        if (cfg.mode === 'delhivery_then_own' || cfg.onNoRider === 'fallback_own') {
            await markHandoff(row.id, `Delhivery unavailable: ${err?.message || err}`);
            return { handled: false };
        }
        if (cfg.onNoRider === 'cancel_refund') {
            await cancelOrderForNoDelivery(row.id, `Delhivery unavailable: ${err?.message || err}`);
            return { handled: true, reason: 'cancelled' };
        }
        await alertAdmin(
            'Delhivery booking failed',
            `Order ${row.id} could not be sent to Delhivery: ${err?.message || err}. Assign it manually.`,
            { orderId: row.id },
        );
        return { handled: true, reason: 'needs_admin' };
    }
}

// ── shipment lifecycle ───────────────────────────────────────────────────────

/** Book a Delhivery rider for an order. Idempotent while an attempt is active. */
export async function startShipment(orderId, { cfg: givenCfg, force = false } = {}) {
    const row = await prisma.foodOrder.findUnique({
        where: { id: String(orderId) },
        include: {
            restaurant: { select: RESTAURANT_SELECT },
            user: { select: { name: true, phone: true } },
            items: { select: { name: true, quantity: true } },
        },
    });
    if (!row) throw new NotFoundError('Order not found');
    if (TERMINAL_ORDER_STATUSES.includes(row.orderStatus)) throw new ValidationError('Order is already closed');

    const existing = await prisma.foodDeliveryShipment.findFirst({ where: { orderId: row.id, active: true } });
    if (existing) return existing;

    const cfg = givenCfg || (await getZoneDeliveryConfig(row.restaurant?.zoneId)) || DEFAULT_ZONE_CONFIG;
    if (!isDelhiveryConfigured()) throw new DelhiveryError('Delhivery credentials are not configured');
    if (!force && !isPrepaid(row)) throw new ValidationError('Only prepaid orders can be sent to Delhivery');

    // One booking at a time per order: claim the dispatch lock our own dispatch uses.
    const { count } = await prisma.foodOrder.updateMany({
        where: { id: row.id, dispatchingAt: null },
        data: { dispatchingAt: new Date() },
    });
    if (count === 0 && !force) {
        const locked = new ValidationError('Order is already being dispatched');
        locked.code = 'DISPATCH_LOCKED';
        throw locked;
    }

    const customerName = row.addrFullName || row.addrName || row.user?.name || 'Customer';
    const customerPhone = row.addrPhone || row.user?.phone || '';

    let shipment = null;
    try {
        const { quote } = await quoteFor(row.restaurant, row, cfg.vehicleMode, { customerName, customerPhone });
        const maxFare = cfg.maxFare === null || cfg.maxFare === undefined ? null : Number(cfg.maxFare);
        if (maxFare && quote.fare > maxFare) {
            throw new DelhiveryError(`Delhivery fare ₹${quote.fare} is above the zone cap of ₹${maxFare}`);
        }

        // When to release the rider. Delhivery aims to reach pickup in ~15 min.
        const pickupTatSec = quote.pickupTatSec || 900;
        const prepSec = (Number(cfg.defaultPrepMinutes) || 15) * 60;
        const ready = row.orderStatus === 'ready_for_pickup';
        let readyToShip = true;
        let confirmDueAt = null;
        if (cfg.confirmPolicy === 'on_ready') {
            readyToShip = ready;
        } else if (cfg.confirmPolicy === 'prep_aligned' && !ready && prepSec > pickupTatSec) {
            readyToShip = false;
            confirmDueAt = new Date(Date.now() + (prepSec - pickupTatSec) * 1000);
        }

        const dropOtp = String(row.deliveryOtp || '').trim() || generateFourDigitDeliveryOtp();
        const pickupOtp = cfg.pickupOtpEnabled ? generateFourDigitDeliveryOtp() : null;

        shipment = await prisma.foodDeliveryShipment.create({
            data: {
                orderId: row.id,
                vehicleMode: cfg.vehicleMode,
                quotedFare: quote.fare,
                dropOtp,
                pickupOtp,
                readyToShip,
                confirmDueAt,
                confirmedAt: readyToShip ? new Date() : null,
            },
        });

        const created = await delhiveryApi.createOrder(
            buildCreatePayload({
                order: row,
                restaurant: row.restaurant,
                items: row.items,
                customerName,
                customerPhone,
                vehicleMode: cfg.vehicleMode,
                readyToShip,
                dropOtp,
                pickupOtp,
                webhookUrl: webhookUrl(),
                webhookApiKey: config.delhivery.webhookApiKey,
            }),
        );
        const providerOrderId = created?.order_id || created?.orderId;
        if (!providerOrderId) throw new DelhiveryError('Delhivery did not return an order id', { body: created });

        shipment = await prisma.foodDeliveryShipment.update({
            where: { id: shipment.id },
            data: { providerOrderId: String(providerOrderId), status: 'created', lastSyncedAt: new Date() },
        });

        const now = new Date();
        const updated = toOrder(
            await prisma.foodOrder.update({
                where: { id: row.id },
                data: {
                    deliveryProvider: 'delhivery',
                    dispatchStatus: 'accepted',
                    dispatchDeliveryPartnerId: null,
                    dispatchAssignedAt: now,
                    dispatchAcceptedAt: now,
                    dispatchingAt: null,
                    deliveryOtp: dropOtp,
                },
                include: orderInclude,
            }),
        );
        await pushStatusHistory(row.id, {
            byRole: 'SYSTEM',
            from: row.orderStatus,
            to: row.orderStatus,
            note: `Sent to Delhivery (${providerOrderId}), quoted ₹${quote.fare}${readyToShip ? '' : `, rider released at ${confirmDueAt?.toISOString() || 'food ready'}`}`,
        });
        emitOrderUpdate(updated);
        logger.info(`[delhivery] order ${row.id} -> ${providerOrderId} (₹${quote.fare}, readyToShip=${readyToShip})`);
        return shipment;
    } catch (err) {
        if (shipment) {
            await prisma.foodDeliveryShipment
                .update({
                    where: { id: shipment.id },
                    data: { active: false, failureReason: String(err?.message || err).slice(0, 500) },
                })
                .catch(() => {});
        }
        throw err;
    } finally {
        await prisma.foodOrder
            .updateMany({ where: { id: row.id, deliveryProvider: 'own' }, data: { dispatchingAt: null } })
            .catch(() => {});
    }
}

/** Release the rider (readyToShip) for a shipment created on hold. */
export async function confirmShipment(shipment) {
    if (!shipment?.providerOrderId || shipment.readyToShip || !shipment.active) return shipment;
    await delhiveryApi.confirmOrder(shipment.providerOrderId, true);
    const updated = await prisma.foodDeliveryShipment.update({
        where: { id: shipment.id },
        data: { readyToShip: true, confirmedAt: new Date(), confirmDueAt: null },
    });
    logger.info(`[delhivery] released rider for ${shipment.providerOrderId}`);
    return updated;
}

/** The restaurant marked the food ready: release the rider now if still held. */
export async function onRestaurantReady(orderId) {
    const shipment = await prisma.foodDeliveryShipment.findFirst({
        where: { orderId: String(orderId), active: true, readyToShip: false },
    });
    if (shipment) await confirmShipment(shipment);
}

/**
 * Cancel the active Delhivery booking for an order (customer, restaurant or
 * admin cancelled it). Never cancels after the rider has the food.
 */
export async function cancelShipmentForOrder(orderId, { reason = CANCEL_REASONS.NOT_REQUIRED, failureReason } = {}) {
    const shipment = await prisma.foodDeliveryShipment.findFirst({ where: { orderId: String(orderId), active: true } });
    if (!shipment) return { cancelled: false, reason: 'no_active_shipment' };

    if (isPastPickup(shipment.fulfilmentStatus)) {
        await alertAdmin(
            'Cancelled order already picked up',
            `Order ${orderId} was cancelled but the Delhivery rider (${shipment.providerOrderId}) already has the food.`,
            { orderId: String(orderId) },
        );
        return { cancelled: false, reason: 'past_pickup' };
    }

    if (shipment.providerOrderId) {
        try {
            await delhiveryApi.cancelOrder(shipment.providerOrderId, reason);
        } catch (err) {
            // Already cancelled / unknown at Delhivery: nothing left to cancel there.
            if (!(err instanceof DelhiveryError) || (err.status !== 400 && err.status !== 404)) throw err;
            logger.warn(`[delhivery] cancel ${shipment.providerOrderId}: ${err.message} (treated as cancelled)`);
        }
    }
    await prisma.foodDeliveryShipment.update({
        where: { id: shipment.id },
        data: {
            active: false,
            cancelledAt: new Date(),
            cancellationReason: reason,
            ...(failureReason ? { failureReason } : {}),
        },
    });
    return { cancelled: true, shipmentId: shipment.id };
}

/** From now on this order is dispatched to our own riders. */
async function markHandoff(orderId, note) {
    const last = await prisma.foodDeliveryShipment.findFirst({
        where: { orderId: String(orderId) },
        orderBy: { createdAt: 'desc' },
    });
    if (last) {
        await prisma.foodDeliveryShipment.update({
            where: { id: last.id },
            data: { active: false, failureReason: HANDOFF_TO_OWN },
        });
    } else {
        await prisma.foodDeliveryShipment.create({
            data: { orderId: String(orderId), active: false, failureReason: HANDOFF_TO_OWN, status: 'not_sent' },
        });
    }
    await prisma.foodOrder.update({
        where: { id: String(orderId) },
        data: {
            deliveryProvider: 'own',
            dispatchStatus: 'unassigned',
            dispatchDeliveryPartnerId: null,
            dispatchAssignedAt: null,
            dispatchAcceptedAt: null,
            dispatchingAt: null,
        },
    });
    await pushStatusHistory(String(orderId), {
        byRole: 'SYSTEM', from: 'delhivery', to: 'own_fleet', note: String(note || 'Handed to own riders').slice(0, 300),
    });
}

async function dispatchToOwnFleet(orderId, note) {
    await markHandoff(orderId, note);
    const { tryAutoAssign } = await import('../../orders/services/order-dispatch.service.js');
    void tryAutoAssign(String(orderId)).catch((err) =>
        logger.warn(`[delhivery] own-fleet dispatch after handoff failed: ${err?.message || err}`),
    );
}

async function cancelOrderForNoDelivery(orderId, note) {
    const { updateOrderStatusAdmin } = await import('../../orders/services/order.service.js');
    await updateOrderStatusAdmin(String(orderId), 'cancelled_by_admin', `No delivery partner available. ${note || ''}`.trim(), null, {
        byRole: 'SYSTEM',
    });
}

/** Delhivery found no rider (timed out, or cancelled on its side). */
async function handleNoRider(orderId, reasonText) {
    const row = await prisma.foodOrder.findUnique({
        where: { id: String(orderId) },
        select: { id: true, orderStatus: true, restaurant: { select: { zoneId: true } } },
    });
    if (!row || TERMINAL_ORDER_STATUSES.includes(row.orderStatus)) return;
    const cfg = (await getZoneDeliveryConfig(row.restaurant?.zoneId)) || DEFAULT_ZONE_CONFIG;
    const attempts = await prisma.foodDeliveryShipment.count({ where: { orderId: row.id } });

    if (cfg.mode === 'delhivery_then_own' || cfg.onNoRider === 'fallback_own') {
        await dispatchToOwnFleet(row.id, reasonText);
        return;
    }
    if (cfg.onNoRider === 'cancel_refund') {
        await cancelOrderForNoDelivery(row.id, reasonText);
        return;
    }
    // notify_admin: one automatic retry with Delhivery, then a person decides.
    if (attempts < MAX_ATTEMPTS) {
        try {
            await startShipment(row.id, { cfg });
            return;
        } catch (err) {
            reasonText = `${reasonText}; retry failed: ${err?.message || err}`;
        }
    }
    await alertAdmin(
        'No Delhivery rider',
        `Order ${row.id}: ${reasonText}. Open Delivery Providers to retry, switch to own riders, or cancel.`,
        { orderId: row.id },
    );
}

// ── state updates (webhook + poller) ─────────────────────────────────────────

async function applyMilestone(orderId, milestone, shipment) {
    const row = await prisma.foodOrder.findUnique({ where: { id: String(orderId) } });
    if (!row || TERMINAL_ORDER_STATUSES.includes(row.orderStatus)) return;
    const now = new Date();
    const rider = shipment.riderName ? `${shipment.riderName} (Delhivery)` : 'The Delhivery rider';

    if (milestone === 'reached_pickup') {
        if (row.deliveryPhase === 'at_pickup' || row.reachedPickupAt) return;
        const updated = toOrder(await prisma.foodOrder.update({
            where: { id: row.id },
            data: { deliveryPhase: 'at_pickup', deliveryStatus: 'reached_pickup', reachedPickupAt: now },
            include: orderInclude,
        }));
        await pushStatusHistory(row.id, { byRole: 'SYSTEM', from: row.deliveryStatus || row.orderStatus, to: 'reached_pickup', note: 'Delhivery rider at restaurant' });
        void notifyOwnersSafely([{ ownerType: 'RESTAURANT', ownerId: row.restaurantId }], {
            title: 'Rider arrived!',
            body: `${rider} has arrived to pick up order ${row.order_id || row.id}.`,
            data: { type: 'rider_arrived', orderMongoId: row.id, partnerName: shipment.riderName || 'Delhivery' },
        }).catch(() => {});
        emitOrderUpdate(updated);
        return;
    }

    if (milestone === 'picked_up') {
        if (!isStatusAdvance(row.orderStatus, 'picked_up')) return;
        const otp = String(row.deliveryOtp || '').trim() || shipment.dropOtp || generateFourDigitDeliveryOtp();
        const updated = toOrder(await prisma.foodOrder.update({
            where: { id: row.id },
            data: {
                orderStatus: 'picked_up',
                deliveryPhase: 'en_route_to_delivery',
                deliveryStatus: 'picked_up',
                pickedUpAt: now,
                deliveryOtp: otp,
                dropOtpRequired: true,
                dropOtpVerified: false,
            },
            include: orderInclude,
        }));
        await pushStatusHistory(row.id, { byRole: 'SYSTEM', from: row.orderStatus, to: 'picked_up', note: 'Picked up by Delhivery rider' });
        emitDeliveryDropOtpToUser(updated, otp);
        void notifyCustomerAndRestaurant({ ...row, orderStatus: 'picked_up' }, 'Order on the way!', `${rider} has picked up your order and is heading your way.`);
        emitOrderUpdate(updated);
        enqueueOrderEvent('picked_up', { orderMongoId: row.id, orderId: row.id, deliveryProvider: 'delhivery' });
        return;
    }

    if (milestone === 'reached_drop') {
        if (row.deliveryPhase === 'at_drop' || row.reachedDropAt) return;
        const updated = toOrder(await prisma.foodOrder.update({
            where: { id: row.id },
            data: { deliveryPhase: 'at_drop', deliveryStatus: 'reached_drop', reachedDropAt: now, dropOtpRequired: true },
            include: orderInclude,
        }));
        await pushStatusHistory(row.id, { byRole: 'SYSTEM', from: row.deliveryStatus || row.orderStatus, to: 'reached_drop', note: 'Delhivery rider at drop' });
        emitDeliveryDropOtpToUser(updated, String(updated.deliveryOtp || row.deliveryOtp || '').trim());
        void notifyCustomerAndRestaurant(row, 'Partner nearby!', `${rider} has reached your location. Share your delivery OTP.`);
        emitOrderUpdate(updated);
        return;
    }

    if (milestone === 'delivered') {
        if (!isStatusAdvance(row.orderStatus, 'delivered')) return;
        const updated = toOrder(await prisma.foodOrder.update({
            where: { id: row.id },
            data: {
                orderStatus: 'delivered',
                deliveryPhase: 'delivered',
                deliveryStatus: 'delivered',
                deliveredAt: now,
                dropOtpVerified: true,
            },
            include: orderInclude,
        }));
        await pushStatusHistory(row.id, { byRole: 'SYSTEM', from: row.orderStatus, to: 'delivered', note: 'Delivered by Delhivery' });

        import('../../user/services/cashback.service.js')
            .then(({ awardOrderCashback }) => awardOrderCashback(row.id))
            .catch((e) => logger.warn(`[delhivery] cashback hook failed: ${e?.message || e}`));
        try {
            const foodTransactionService = await import('../../orders/services/foodTransaction.service.js');
            await foodTransactionService.updateTransactionStatus(row.id, 'payment_snapshot_sync', {
                status: 'captured',
                recordedByRole: 'SYSTEM',
                recordedById: null,
                note: `Delivered by Delhivery (${shipment.providerOrderId})`,
            });
        } catch (err) {
            logger.warn(`[delhivery] transaction capture failed for ${row.id}: ${err?.message || err}`);
        }

        void notifyCustomerAndRestaurant({ ...row, orderStatus: 'delivered' }, 'Order delivered!', "Hope you enjoyed your meal! Don't forget to rate your experience.");
        emitOrderUpdate(updated);
        enqueueOrderEvent('delivery_completed', { orderMongoId: row.id, orderId: row.id, deliveryProvider: 'delhivery' });
    }
}

/**
 * Apply one Delhivery payload (webhook or Track response). Forward-only and
 * idempotent: a duplicate or late event is recorded but changes nothing.
 */
export async function applyProviderUpdate(body, { source = 'webhook' } = {}) {
    const t = normalizeTracking(body);
    if (!t.providerOrderId) return { applied: false, reason: 'no_order_id' };

    const shipment = await prisma.foodDeliveryShipment.findUnique({ where: { providerOrderId: t.providerOrderId } });
    const prev = shipment?.fulfilmentStatus || 'pending';
    const next = t.fulfilmentStatus;
    const forward = Boolean(shipment && next && rankOf(next) > rankOf(prev));

    await prisma.foodDeliveryProviderEvent.create({
        data: {
            shipmentId: shipment?.id || null,
            providerOrderId: t.providerOrderId,
            source,
            fulfilmentStatus: next,
            applied: forward,
            payload: body ?? {},
        },
    });
    if (!shipment) return { applied: false, reason: 'unknown_order' };

    const now = new Date();
    const patch = { lastSyncedAt: now, lastPayload: body ?? {} };
    if (source === 'webhook') patch.lastEventAt = now;
    if (forward) patch.fulfilmentStatus = next;
    if (t.status) patch.status = t.status;
    if (t.nextDestination !== undefined) patch.nextDestination = t.nextDestination;
    if (t.trackingUrl) patch.trackingUrl = t.trackingUrl;
    if (t.rider) {
        if (t.rider.name) patch.riderName = t.rider.name.slice(0, 120);
        if (t.rider.phone) patch.riderPhone = t.rider.phone.slice(0, 20);
        if (t.rider.vehicleNumber) patch.vehicleNumber = t.rider.vehicleNumber.slice(0, 30);
        if (t.rider.vehicleType) patch.vehicleType = t.rider.vehicleType.slice(0, 30);
        if (t.rider.lat !== null && t.rider.lng !== null) {
            patch.riderLat = t.rider.lat;
            patch.riderLng = t.rider.lng;
            patch.riderLocationAt = now;
        }
    }
    if (next === 'order_delivered') {
        patch.active = false;
        if (t.fare !== null) patch.finalFare = t.fare;
    }
    const updatedShipment = await prisma.foodDeliveryShipment.update({ where: { id: shipment.id }, data: patch });

    // Live location onto the order too: the tracking map reads riderLat/riderLng.
    if (shipment.active && patch.riderLat !== undefined) {
        const orderRow = await prisma.foodOrder.update({
            where: { id: shipment.orderId },
            data: { riderLat: patch.riderLat, riderLng: patch.riderLng },
            select: { id: true, userId: true, restaurantId: true },
        });
        emitRiderLocation(orderRow, patch.riderLat, patch.riderLng);
    }

    // An attempt we already closed (we cancelled it) must not move the order.
    if (!shipment.active || !forward) return { applied: forward, shipmentId: shipment.id };

    if (next === 'cancelled') {
        await prisma.foodDeliveryShipment.update({
            where: { id: shipment.id },
            data: { active: false, cancelledAt: now, cancellationReason: t.cancellationReason || 'cancelled by Delhivery' },
        });
        await handleNoRider(shipment.orderId, `Delhivery cancelled ${t.providerOrderId}: ${t.cancellationReason || 'no reason given'}`);
        return { applied: true, shipmentId: shipment.id };
    }

    if (next === 'agent_assigned' && rankOf(prev) < rankOf('agent_assigned')) {
        const row = await prisma.foodOrder.findUnique({ where: { id: shipment.orderId }, include: orderInclude });
        if (row) {
            void notifyOwnersSafely([{ ownerType: 'USER', ownerId: row.userId }], {
                title: 'Delivery partner assigned',
                body: `${updatedShipment.riderName || 'A Delhivery rider'} will pick up your order.`,
                data: { type: 'order_status_update', orderId: row.id, orderMongoId: row.id, orderStatus: row.orderStatus },
            }).catch(() => {});
            emitOrderUpdate(toOrder(row));
        }
    }

    for (const milestone of milestonesBetween(prev, next)) {
        await applyMilestone(shipment.orderId, milestone, updatedShipment);
    }
    return { applied: true, shipmentId: shipment.id };
}

/** Pull the current state from the Track API and apply it. */
export async function syncShipment(shipment) {
    if (!shipment?.providerOrderId) return null;
    const data = await delhiveryApi.trackOrder(shipment.providerOrderId);
    return applyProviderUpdate(data, { source: 'poll' });
}

// ── scheduler tick ───────────────────────────────────────────────────────────

const SYNC_STALE_MS = 90 * 1000;

async function zoneConfigsById() {
    const rows = await prisma.foodZoneDeliveryConfig.findMany({ where: { isEnabled: true } });
    return new Map(rows.map((r) => [r.zoneId, r]));
}

/**
 * Runs every minute in the scheduler: releases held riders on time, gives up
 * on bookings with no rider, backfills missed webhooks, cancels bookings for
 * orders cancelled elsewhere, and escalates own-first zones to Delhivery.
 */
export async function runDelhiveryJobs() {
    if (!isDelhiveryConfigured()) return { skipped: 'not_configured' };
    const now = new Date();
    const stats = { confirmed: 0, timedOut: 0, synced: 0, orphansCancelled: 0, escalated: 0, errors: 0 };
    const configs = await zoneConfigsById();

    const active = await prisma.foodDeliveryShipment.findMany({
        where: { active: true, providerOrderId: { not: null } },
        include: { order: { select: { id: true, orderStatus: true, restaurant: { select: { zoneId: true } } } } },
        take: 200,
    });

    for (const s of active) {
        try {
            // 1. Order cancelled somewhere we did not hook: cancel the booking.
            if (TERMINAL_ORDER_STATUSES.includes(s.order.orderStatus) && s.order.orderStatus !== 'delivered') {
                await cancelShipmentForOrder(s.orderId);
                stats.orphansCancelled += 1;
                continue;
            }
            // 2. Held rider whose release time has come.
            if (!s.readyToShip && s.confirmDueAt && s.confirmDueAt <= now) {
                await confirmShipment(s);
                stats.confirmed += 1;
                continue;
            }
            // 3. Still no rider after the zone's timeout (counted from release).
            const cfg = configs.get(s.order.restaurant?.zoneId) || DEFAULT_ZONE_CONFIG;
            const searchingSince = s.confirmedAt || s.createdAt;
            const timeoutMs = (Number(cfg.assignTimeoutMin) || 10) * 60 * 1000;
            if (s.readyToShip && isAwaitingRider(s.fulfilmentStatus) && now - searchingSince > timeoutMs) {
                await cancelShipmentForOrder(s.orderId, { reason: CANCEL_REASONS.NO_DRIVER, failureReason: 'no_rider_timeout' });
                await handleNoRider(s.orderId, `no rider within ${cfg.assignTimeoutMin} min`);
                stats.timedOut += 1;
                continue;
            }
            // 4. Backfill a missed webhook.
            if (!s.lastSyncedAt || now - s.lastSyncedAt > SYNC_STALE_MS) {
                await syncShipment(s);
                stats.synced += 1;
            }
        } catch (err) {
            stats.errors += 1;
            logger.warn(`[delhivery] job for shipment ${s.id} failed: ${err?.message || err}`);
        }
    }

    // 5. Own-first zones: hand over orders our riders have not taken in time.
    for (const cfg of configs.values()) {
        if (cfg.mode !== 'own_then_delhivery') continue;
        const cutoff = new Date(now.getTime() - (Number(cfg.assignTimeoutMin) || 10) * 60 * 1000);
        const waiting = await prisma.foodOrder.findMany({
            where: {
                deliveryProvider: 'own',
                orderStatus: { in: DISPATCHABLE },
                dispatchAcceptedAt: null,
                restaurant: { zoneId: cfg.zoneId },
                shipments: { none: {} },
                statusHistory: { some: { to: { in: ['confirmed', 'preparing'] }, at: { lt: cutoff } } },
            },
            select: { id: true, paymentMethod: true, paymentStatus: true },
            take: 20,
        });
        for (const o of waiting) {
            if (!isPrepaid(o)) continue;
            try {
                await prisma.foodOrder.update({
                    where: { id: o.id },
                    data: { dispatchStatus: 'unassigned', dispatchDeliveryPartnerId: null, dispatchAssignedAt: null, dispatchingAt: null },
                });
                await startShipment(o.id, { cfg });
                stats.escalated += 1;
            } catch (err) {
                stats.errors += 1;
                logger.warn(`[delhivery] escalation of ${o.id} failed: ${err?.message || err}`);
            }
        }
    }

    if (Object.values(stats).some((n) => n > 0)) logger.info(`[delhivery] jobs: ${JSON.stringify(stats)}`);
    return stats;
}

// ── read models for apps + admin ─────────────────────────────────────────────

/**
 * What the apps show for a Delhivery order. The pickup OTP goes to the
 * restaurant (and admin) only — the customer must never see it.
 */
export async function externalDeliveryFor(orderId, { audience = 'user' } = {}) {
    const s = await prisma.foodDeliveryShipment.findFirst({
        where: { orderId: String(orderId), failureReason: { not: HANDOFF_TO_OWN } },
        orderBy: { createdAt: 'desc' },
    });
    if (!s) return null;
    const base = {
        provider: 'delhivery',
        providerOrderId: s.providerOrderId,
        fulfilmentStatus: s.fulfilmentStatus,
        statusText: describeFulfilment(s.fulfilmentStatus),
        active: s.active,
        riderName: s.riderName,
        riderPhone: s.riderPhone,
        vehicleNumber: s.vehicleNumber,
        vehicleType: s.vehicleType,
        riderLat: s.riderLat,
        riderLng: s.riderLng,
        riderLocationAt: s.riderLocationAt,
        trackingUrl: s.trackingUrl,
    };
    if (audience === 'restaurant' || audience === 'admin') base.pickupOtp = s.pickupOtp;
    if (audience === 'admin') {
        Object.assign(base, {
            shipmentId: s.id,
            quotedFare: s.quotedFare === null ? null : Number(s.quotedFare),
            finalFare: s.finalFare === null ? null : Number(s.finalFare),
            readyToShip: s.readyToShip,
            confirmDueAt: s.confirmDueAt,
            cancellationReason: s.cancellationReason,
            failureReason: s.failureReason,
        });
    }
    return base;
}

export const providerSummary = () => ({
    configured: isDelhiveryConfigured(),
    env: config.delhivery.env,
    baseUrl: delhiveryBaseUrl(),
    webhookUrl: webhookUrl(),
    webhookKeySet: Boolean(config.delhivery.webhookApiKey),
});

export async function checkCredentials() {
    if (!isDelhiveryConfigured()) return { ok: false, message: 'Credentials are not set in Backend/.env' };
    try {
        await getAccessToken({ force: true });
        return { ok: true, message: `Connected to Delhivery ${config.delhivery.env}` };
    } catch (err) {
        return { ok: false, message: err?.message || String(err) };
    }
}

/** Quote a short trip inside a zone, to check a zone works before turning it on. */
export async function testQuoteForZone(zoneId, { pickup, drop, vehicleMode } = {}) {
    const zone = await prisma.foodZone.findUnique({ where: { id: String(zoneId) } });
    if (!zone) throw new NotFoundError('Zone not found');
    if (!isDelhiveryConfigured()) throw new ValidationError('Add Delhivery credentials to Backend/.env first');

    let origin = pickup;
    if (!origin) {
        const ring = Array.isArray(zone.coordinates) ? zone.coordinates : [];
        const pts = ring.map((p) => [Number(p.latitude ?? p.lat), Number(p.longitude ?? p.lng)]).filter(([a, b]) => Number.isFinite(a) && Number.isFinite(b));
        if (!pts.length) throw new ValidationError('Zone has no boundary to test from');
        origin = {
            lat: pts.reduce((s, p) => s + p[0], 0) / pts.length,
            lng: pts.reduce((s, p) => s + p[1], 0) / pts.length,
        };
    }
    const destination = drop || { lat: origin.lat + 0.015, lng: origin.lng + 0.01 };
    const cfg = (await getZoneDeliveryConfig(zoneId)) || DEFAULT_ZONE_CONFIG;
    try {
        const data = await delhiveryApi.quote(
            buildQuotePayload({
                restaurant: { latitude: origin.lat, longitude: origin.lng, restaurantName: `${zone.name} test pickup` },
                order: { addrLat: destination.lat, addrLng: destination.lng },
                customerName: 'Zone test',
            }),
        );
        return {
            serviceable: true,
            pickup: origin,
            drop: destination,
            selected: pickQuote(data, vehicleMode || cfg.vehicleMode),
            vehicles: (data?.vehicles || []).map((v) => pickQuote({ vehicles: [v] }, v.type)),
        };
    } catch (err) {
        if (err instanceof DelhiveryError && err.isNotServiceable) {
            return { serviceable: false, pickup: origin, drop: destination, message: err.message };
        }
        throw new ValidationError(`Delhivery quote failed: ${err?.message || err}`);
    }
}

export { CANCEL_REASONS, dispatchToOwnFleet };

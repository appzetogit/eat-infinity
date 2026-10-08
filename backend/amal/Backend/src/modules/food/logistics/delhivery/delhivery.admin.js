import express from 'express';
import { z } from 'zod';
import { prisma } from '../../../../config/prisma.js';
import { sendResponse } from '../../../../utils/response.js';
import { isId } from '../../../../utils/helpers.js';
import { ValidationError, NotFoundError } from '../../../../core/auth/errors.js';
import { TERMINAL_ORDER_STATUSES } from '../../orders/services/order.helpers.js';
import { VEHICLE_MODES, CANCEL_REASONS } from './delhivery.mapper.js';
import {
    DEFAULT_ZONE_CONFIG,
    HANDOFF_TO_OWN,
    cancelShipmentForOrder,
    checkCredentials,
    dispatchToOwnFleet,
    externalDeliveryFor,
    invalidateZoneConfig,
    providerSummary,
    startShipment,
    syncShipment,
    testQuoteForZone,
} from './delhivery.service.js';

/**
 * Admin API for third-party delivery, mounted at /food/admin/delivery-providers.
 * The path starts with /delivery, so admin.routes.js guards it with the
 * delivery_management permission like every other delivery screen.
 */

const router = express.Router();

const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

const asDecimal = (v) => (v === null || v === undefined ? null : Number(v));

const serializeConfig = (zone, cfg) => ({
    zoneId: zone.id,
    zoneName: zone.name || zone.zoneName,
    zoneActive: zone.isActive,
    configured: Boolean(cfg),
    ...DEFAULT_ZONE_CONFIG,
    ...(cfg
        ? {
            mode: cfg.mode,
            isEnabled: cfg.isEnabled,
            vehicleMode: cfg.vehicleMode,
            assignTimeoutMin: cfg.assignTimeoutMin,
            onNoRider: cfg.onNoRider,
            confirmPolicy: cfg.confirmPolicy,
            defaultPrepMinutes: cfg.defaultPrepMinutes,
            maxFare: asDecimal(cfg.maxFare),
            checkServiceability: cfg.checkServiceability,
            pickupOtpEnabled: cfg.pickupOtpEnabled,
            updatedAt: cfg.updatedAt,
        }
        : {}),
});

// ── overview ─────────────────────────────────────────────────────────────────

router.get('/', wrap(async (req, res) => {
    const [zones, activeCount, attentionCount] = await Promise.all([
        prisma.foodZone.findMany({ orderBy: { name: 'asc' }, include: { deliveryConfig: true } }),
        prisma.foodDeliveryShipment.count({ where: { active: true } }),
        countAttention(),
    ]);
    return sendResponse(res, 200, 'Delivery providers', {
        provider: providerSummary(),
        vehicleModes: VEHICLE_MODES,
        zones: zones.map((z) => serializeConfig(z, z.deliveryConfig)),
        counts: { active: activeCount, attention: attentionCount },
    });
}));

router.post('/check-credentials', wrap(async (req, res) => {
    return sendResponse(res, 200, 'Credential check', await checkCredentials());
}));

// ── zone settings ────────────────────────────────────────────────────────────

const zoneConfigSchema = z.object({
    mode: z.enum(['own', 'delhivery', 'delhivery_then_own', 'own_then_delhivery']),
    isEnabled: z.boolean(),
    vehicleMode: z.enum(VEHICLE_MODES),
    assignTimeoutMin: z.number().int().min(2).max(60),
    onNoRider: z.enum(['fallback_own', 'cancel_refund', 'notify_admin']),
    confirmPolicy: z.enum(['on_accept', 'prep_aligned', 'on_ready']),
    defaultPrepMinutes: z.number().int().min(0).max(120),
    maxFare: z.number().positive().max(100000).nullable(),
    checkServiceability: z.boolean(),
    pickupOtpEnabled: z.boolean(),
});

router.put('/zones/:zoneId', wrap(async (req, res) => {
    const { zoneId } = req.params;
    if (!isId(zoneId)) throw new ValidationError('Invalid zone id');
    const zone = await prisma.foodZone.findUnique({ where: { id: zoneId } });
    if (!zone) throw new NotFoundError('Zone not found');

    const body = req.body || {};
    const parsed = zoneConfigSchema.safeParse({
        ...body,
        assignTimeoutMin: Number(body.assignTimeoutMin),
        defaultPrepMinutes: Number(body.defaultPrepMinutes),
        maxFare: body.maxFare === '' || body.maxFare === null || body.maxFare === undefined ? null : Number(body.maxFare),
    });
    if (!parsed.success) {
        const issue = parsed.error.errors[0];
        throw new ValidationError(`${issue.path.join('.')}: ${issue.message}`);
    }
    if (parsed.data.pickupOtpEnabled) {
        // The restaurant would need to see the code to hand it over, and no app
        // screen shows it yet — a rider would be stuck at the counter.
        throw new ValidationError('Pickup OTP needs the restaurant app to show the code; leave it off for now.');
    }

    const data = { ...parsed.data, updatedByAdminId: req.user?.userId ? String(req.user.userId) : null };
    const saved = await prisma.foodZoneDeliveryConfig.upsert({
        where: { zoneId },
        create: { zoneId, ...data },
        update: data,
    });
    invalidateZoneConfig(zoneId);
    return sendResponse(res, 200, 'Zone delivery settings saved', serializeConfig(zone, saved));
}));

router.post('/zones/:zoneId/test-quote', wrap(async (req, res) => {
    const { zoneId } = req.params;
    if (!isId(zoneId)) throw new ValidationError('Invalid zone id');
    const { pickup, drop, vehicleMode } = req.body || {};
    const result = await testQuoteForZone(zoneId, { pickup, drop, vehicleMode });
    return sendResponse(res, 200, result.serviceable ? 'Serviceable' : 'Not serviceable', result);
}));

// ── shipments ────────────────────────────────────────────────────────────────

/** Orders with Delhivery that have no live booking and are not finished. */
const attentionWhere = () => ({
    deliveryProvider: 'delhivery',
    orderStatus: { notIn: TERMINAL_ORDER_STATUSES },
    shipments: { none: { active: true } },
});

const countAttention = () => prisma.foodOrder.count({ where: attentionWhere() });

const ORDER_SELECT = {
    id: true, order_id: true, orderStatus: true, total: true, createdAt: true, deliveryProvider: true,
    restaurant: { select: { restaurantName: true, zone: { select: { name: true } } } },
};

const serializeShipment = (s) => ({
    id: s.id,
    orderId: s.orderId,
    order: s.order
        ? {
            id: s.order.id,
            orderNumber: s.order.order_id || s.order.id,
            orderStatus: s.order.orderStatus,
            total: asDecimal(s.order.total),
            restaurantName: s.order.restaurant?.restaurantName || '',
            zoneName: s.order.restaurant?.zone?.name || '',
        }
        : null,
    providerOrderId: s.providerOrderId,
    status: s.status,
    fulfilmentStatus: s.fulfilmentStatus,
    active: s.active,
    vehicleMode: s.vehicleMode,
    quotedFare: asDecimal(s.quotedFare),
    finalFare: asDecimal(s.finalFare),
    readyToShip: s.readyToShip,
    confirmDueAt: s.confirmDueAt,
    riderName: s.riderName,
    riderPhone: s.riderPhone,
    vehicleNumber: s.vehicleNumber,
    trackingUrl: s.trackingUrl,
    cancellationReason: s.cancellationReason,
    failureReason: s.failureReason,
    lastSyncedAt: s.lastSyncedAt,
    createdAt: s.createdAt,
});

router.get('/shipments', wrap(async (req, res) => {
    const view = ['active', 'attention', 'all'].includes(req.query.view) ? req.query.view : 'active';
    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 25));
    const search = String(req.query.search || '').trim();

    if (view === 'attention') {
        const where = attentionWhere();
        const [orders, total] = await Promise.all([
            prisma.foodOrder.findMany({
                where,
                select: { ...ORDER_SELECT, shipments: { orderBy: { createdAt: 'desc' }, take: 1 } },
                orderBy: { createdAt: 'desc' },
                skip: (page - 1) * limit,
                take: limit,
            }),
            prisma.foodOrder.count({ where }),
        ]);
        const items = orders.map((o) => {
            const last = o.shipments[0];
            return last
                ? serializeShipment({ ...last, order: o })
                : { id: null, orderId: o.id, order: serializeShipment({ order: o }).order, active: false, failureReason: 'never_sent' };
        });
        return sendResponse(res, 200, 'Orders needing attention', { items, total, page, limit });
    }

    // `failureReason: { not: X }` alone would drop NULLs in SQL, and NULL is the
    // normal case, hence the explicit OR.
    const finalWhere = {
        AND: [
            { provider: 'delhivery' },
            { OR: [{ failureReason: null }, { failureReason: { not: HANDOFF_TO_OWN } }] },
            ...(view === 'active' ? [{ active: true }] : []),
            ...(search
                ? [{
                    OR: [
                        { providerOrderId: { contains: search, mode: 'insensitive' } },
                        { order: { order_id: { contains: search, mode: 'insensitive' } } },
                        { order: { restaurant: { restaurantName: { contains: search, mode: 'insensitive' } } } },
                    ],
                }]
                : []),
        ],
    };
    const [rows, total] = await Promise.all([
        prisma.foodDeliveryShipment.findMany({
            where: finalWhere,
            include: { order: { select: ORDER_SELECT } },
            orderBy: { createdAt: 'desc' },
            skip: (page - 1) * limit,
            take: limit,
        }),
        prisma.foodDeliveryShipment.count({ where: finalWhere }),
    ]);
    return sendResponse(res, 200, 'Shipments', { items: rows.map(serializeShipment), total, page, limit });
}));

router.get('/orders/:orderId', wrap(async (req, res) => {
    const { orderId } = req.params;
    if (!isId(orderId)) throw new ValidationError('Invalid order id');
    const [external, events] = await Promise.all([
        externalDeliveryFor(orderId, { audience: 'admin' }),
        prisma.foodDeliveryProviderEvent.findMany({
            where: { shipment: { orderId } },
            orderBy: { createdAt: 'desc' },
            take: 50,
            select: { id: true, source: true, fulfilmentStatus: true, applied: true, createdAt: true },
        }),
    ]);
    return sendResponse(res, 200, 'Delivery details', { external, events });
}));

// ── manual actions ───────────────────────────────────────────────────────────

const loadShipment = async (id) => {
    if (!isId(id)) throw new ValidationError('Invalid shipment id');
    const s = await prisma.foodDeliveryShipment.findUnique({ where: { id } });
    if (!s) throw new NotFoundError('Shipment not found');
    return s;
};

router.post('/shipments/:id/resync', wrap(async (req, res) => {
    const s = await loadShipment(req.params.id);
    if (!s.providerOrderId) throw new ValidationError('This attempt never reached Delhivery');
    const result = await syncShipment(s);
    return sendResponse(res, 200, 'Synced with Delhivery', result);
}));

router.post('/shipments/:id/cancel', wrap(async (req, res) => {
    const s = await loadShipment(req.params.id);
    const reason = Object.values(CANCEL_REASONS).includes(req.body?.reason) ? req.body.reason : CANCEL_REASONS.NOT_REQUIRED;
    const result = await cancelShipmentForOrder(s.orderId, { reason, failureReason: 'cancelled_by_admin' });
    if (!result.cancelled && result.reason === 'past_pickup') {
        throw new ValidationError('The rider already has the food; it cannot be cancelled now.');
    }
    return sendResponse(res, 200, 'Delhivery booking cancelled', result);
}));

const assertOpenOrder = async (orderId) => {
    if (!isId(orderId)) throw new ValidationError('Invalid order id');
    const o = await prisma.foodOrder.findUnique({ where: { id: orderId }, select: { id: true, orderStatus: true } });
    if (!o) throw new NotFoundError('Order not found');
    if (TERMINAL_ORDER_STATUSES.includes(o.orderStatus)) throw new ValidationError('Order is already closed');
    return o;
};

router.post('/orders/:orderId/retry', wrap(async (req, res) => {
    const o = await assertOpenOrder(req.params.orderId);
    await cancelShipmentForOrder(o.id, { failureReason: 'replaced_by_admin_retry' });
    const shipment = await startShipment(o.id, { force: true });
    return sendResponse(res, 200, 'Sent to Delhivery again', serializeShipment(shipment));
}));

router.post('/orders/:orderId/switch-to-own', wrap(async (req, res) => {
    const o = await assertOpenOrder(req.params.orderId);
    const result = await cancelShipmentForOrder(o.id, { failureReason: 'switched_by_admin' });
    if (!result.cancelled && result.reason === 'past_pickup') {
        throw new ValidationError('The Delhivery rider already has the food; it cannot be reassigned.');
    }
    await dispatchToOwnFleet(o.id, 'Switched to own riders by admin');
    return sendResponse(res, 200, 'Handed to own riders', { orderId: o.id });
}));

export default router;

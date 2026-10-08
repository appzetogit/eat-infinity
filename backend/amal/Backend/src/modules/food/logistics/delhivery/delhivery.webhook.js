import crypto from 'node:crypto';
import express from 'express';
import { config } from '../../../../config/env.js';
import { logger } from '../../../../utils/logger.js';
import { applyProviderUpdate } from './delhivery.service.js';

/**
 * POST /api/v1/webhooks/delhivery — Delhivery's status callbacks.
 *
 * Authenticated with the xApiKey we hand Delhivery on every Create Order: it
 * comes back as the X-Api-Key header. (The contract also offers an HMAC
 * signature, but does not say how it is computed; until Delhivery confirms
 * the algorithm the API key is the check.)
 *
 * Always 200 once authenticated, even for an order we do not know: a 4xx would
 * only make Delhivery retry something that can never succeed. The work is
 * cheap and idempotent, and the scheduler's poller catches anything this
 * endpoint misses.
 */

const keyMatches = (given) => {
    const expected = config.delhivery.webhookApiKey;
    if (!expected || !given) return false;
    const a = Buffer.from(String(given));
    const b = Buffer.from(String(expected));
    return a.length === b.length && crypto.timingSafeEqual(a, b);
};

const router = express.Router();

router.post('/', async (req, res) => {
    if (!keyMatches(req.get('X-Api-Key'))) {
        logger.warn(`[delhivery] webhook rejected: bad or missing X-Api-Key from ${req.ip}`);
        return res.status(401).json({ success: false, message: 'Unauthorized' });
    }
    try {
        const result = await applyProviderUpdate(req.body, { source: 'webhook' });
        return res.status(200).json({ success: true, ...result });
    } catch (err) {
        // Logged, still 200: the poller will reconcile this order shortly.
        logger.error(`[delhivery] webhook processing failed: ${err?.message || err}`);
        return res.status(200).json({ success: true, deferred: true });
    }
});

export default router;

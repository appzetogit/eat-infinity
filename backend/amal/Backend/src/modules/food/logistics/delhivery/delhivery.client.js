import crypto from 'node:crypto';
import { config } from '../../../../config/env.js';
import { logger } from '../../../../utils/logger.js';

/**
 * Thin HTTP client for Delhivery Local (Direct Intracity APIs, contract V6).
 *
 * Every call needs three headers: the access token (X-COREOS-ACCESS), a unique
 * request id (X-COREOS-REQUEST-ID) and our client code (X-CLIENT-CODE). The
 * token lasts 24 h; it is cached per process and refreshed an hour early, and
 * a 401 forces one refresh-and-retry.
 *
 * Retries are deliberately narrow. Quote and Track are reads and are retried
 * once on a network error or 5xx. Create, Confirm and Cancel are not: a create
 * that timed out may still have booked a rider, and blindly sending it again
 * could book two.
 */

const BASE_URLS = {
    sandbox: 'https://delvjkninl.sandbox.getos1.com',
    production: 'https://ztietgya0i.logistax.io',
};

const TIMEOUT_MS = 10_000;
const TOKEN_REFRESH_MARGIN_MS = 60 * 60 * 1000;

export class DelhiveryError extends Error {
    constructor(message, { status = 0, code = null, body = null } = {}) {
        super(message);
        this.name = 'DelhiveryError';
        this.status = status;
        /** Delhivery's own error code from the body (e.g. 424 = not serviceable). */
        this.code = code;
        this.body = body;
    }

    get isNotServiceable() {
        return this.code === 424 || this.status === 424;
    }
}

const cfg = () => config.delhivery;

export const isDelhiveryConfigured = () =>
    Boolean(cfg().clientId && cfg().clientSecret && cfg().clientCode);

export const delhiveryBaseUrl = () => BASE_URLS[cfg().env] || BASE_URLS.sandbox;

let tokenCache = { token: null, expiresAt: 0 };
let tokenInFlight = null;

const requestId = () => crypto.randomUUID();

async function rawFetch(url, { method = 'GET', headers = {}, body } = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
        const res = await fetch(url, {
            method,
            headers: { 'Content-Type': 'application/json', Accept: 'application/json', ...headers },
            body: body === undefined ? undefined : JSON.stringify(body),
            signal: controller.signal,
        });
        const text = await res.text();
        let json = null;
        try {
            json = text ? JSON.parse(text) : null;
        } catch {
            json = { raw: text };
        }
        return { status: res.status, ok: res.ok, json };
    } catch (err) {
        const reason = err?.name === 'AbortError' ? `timed out after ${TIMEOUT_MS}ms` : err?.message || String(err);
        throw new DelhiveryError(`Delhivery unreachable: ${reason}`, { status: 0 });
    } finally {
        clearTimeout(timer);
    }
}

const errorFrom = (status, json) => {
    const code = Number(json?.error?.code) || null;
    const message = json?.error?.message || json?.message || `Delhivery responded ${status}`;
    return new DelhiveryError(message, { status, code, body: json });
};

async function fetchToken() {
    if (!isDelhiveryConfigured()) {
        throw new DelhiveryError('Delhivery credentials are not configured');
    }
    const { status, ok, json } = await rawFetch(
        `${delhiveryBaseUrl()}/core/api/v1/aaa/auth/client-credentials`,
        {
            method: 'POST',
            headers: { 'X-COREOS-REQUEST-ID': requestId() },
            body: {
                clientId: cfg().clientId,
                clientSecret: cfg().clientSecret,
                audience: 'platform:app:coreos',
            },
        },
    );
    const token = json?.data?.accessToken;
    if (!ok || !token) throw errorFrom(status, json);

    const ttlMs = (Number(json.data.expiresIn) || 86400) * 1000;
    tokenCache = { token, expiresAt: Date.now() + ttlMs - TOKEN_REFRESH_MARGIN_MS };
    return token;
}

/** A valid access token, fetched once even when many calls arrive together. */
export async function getAccessToken({ force = false } = {}) {
    if (!force && tokenCache.token && Date.now() < tokenCache.expiresAt) return tokenCache.token;
    if (!tokenInFlight) {
        tokenInFlight = fetchToken().finally(() => {
            tokenInFlight = null;
        });
    }
    return tokenInFlight;
}

export function clearTokenCache() {
    tokenCache = { token: null, expiresAt: 0 };
}

/**
 * One authenticated call. `retryable` allows a single retry on a network error
 * or 5xx; a 401 is always refreshed and retried once.
 */
async function call(method, path, body, { retryable = false } = {}) {
    const send = async (token) =>
        rawFetch(`${delhiveryBaseUrl()}${path}`, {
            method,
            body,
            headers: {
                'X-COREOS-ACCESS': token,
                'X-COREOS-REQUEST-ID': requestId(),
                'X-CLIENT-CODE': cfg().clientCode,
            },
        });

    let token = await getAccessToken();
    let res;
    try {
        res = await send(token);
    } catch (err) {
        if (!retryable) throw err;
        await new Promise((r) => setTimeout(r, 500));
        res = await send(token);
    }

    if (res.status === 401) {
        token = await getAccessToken({ force: true });
        res = await send(token);
    } else if (retryable && res.status >= 500) {
        await new Promise((r) => setTimeout(r, 500));
        res = await send(token);
    }

    if (!res.ok || res.json?.success === false) {
        const err = errorFrom(res.status, res.json);
        logger.warn(`[delhivery] ${method} ${path} -> ${res.status} ${err.message}`);
        throw err;
    }
    return res.json?.data ?? res.json;
}

export const delhiveryApi = {
    quote: (payload) => call('POST', '/local/api/proxy/v1/shipper/pricing/quote', payload, { retryable: true }),
    createOrder: (payload) => call('POST', '/local/api/proxy/v1/shipper/orders/create', payload),
    confirmOrder: (orderId, readyToShip = true) =>
        call('POST', '/local/api/proxy/v1/shipper/orders/confirm', { orderId, readyToShip }),
    cancelOrder: (orderId, cancellationReason) =>
        call('POST', '/local/api/proxy/v1/shipper/orders/cancel', { orderId, cancellationReason }),
    trackOrder: (orderId) =>
        call('GET', `/local/api/proxy/v1/shipper/orders/${encodeURIComponent(orderId)}`, undefined, { retryable: true }),
};

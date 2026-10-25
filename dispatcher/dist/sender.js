"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.processJob = processJob;
const crypto = __importStar(require("crypto"));
const db_1 = require("./db");
async function processJob(job) {
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const eventId = job.event_id;
    const rawBody = job.raw_body;
    const secret = job.secret;
    const hmac = crypto.createHmac('sha256', secret)
        .update(`${timestamp}.${eventId}.${rawBody}`, 'utf8')
        .digest('hex');
    const headers = {
        'Content-Type': 'application/json',
        'x-gc-timestamp': timestamp,
        'x-gc-event-id': eventId,
        'x-gc-signature': `sha256=${hmac}`
    };
    const startTime = Date.now();
    let outcome = 'RETRY';
    let httpStatus = 0;
    let responseBody = '';
    let errorMessage = '';
    let baseBackoff = Math.pow(2, Number(job.attempt_count) || 0) * 60;
    if (baseBackoff > 3600 || !Number.isFinite(baseBackoff))
        baseBackoff = 3600;
    let retryAfter = Math.floor(baseBackoff + Math.random() * 10);
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(new Error('TIMEOUT')), 60000);
    try {
        if (!job.endpoint_url.startsWith('https://') && process.env.ALLOW_HTTP_OFFLINE_TEST !== 'true') {
            throw new Error('Endpoint URL must use HTTPS');
        }
        const res = await globalThis.fetch(job.endpoint_url, {
            method: 'POST',
            headers,
            body: rawBody,
            signal: controller.signal,
            redirect: 'error'
        });
        httpStatus = res.status;
        if (res.headers.has('retry-after')) {
            const raStr = res.headers.get('retry-after') || '';
            let parsedSeconds = NaN;
            if (/^\d+$/.test(raStr.trim())) {
                parsedSeconds = parseInt(raStr.trim(), 10);
            }
            else {
                const parsedDate = Date.parse(raStr.trim());
                if (!isNaN(parsedDate)) {
                    parsedSeconds = Math.ceil((parsedDate - Date.now()) / 1000);
                }
            }
            if (!isNaN(parsedSeconds)) {
                if (parsedSeconds < 1)
                    parsedSeconds = 1;
                if (parsedSeconds > 3600)
                    parsedSeconds = 3600;
                retryAfter = parsedSeconds;
            }
        }
        let totalBytes = 0;
        let chunks = [];
        if (res.body) {
            for await (const chunk of res.body) {
                totalBytes += chunk.length;
                if (totalBytes > 51200)
                    throw new Error('OVERSIZED_RESPONSE');
                chunks.push(Buffer.from(chunk));
            }
        }
        const text = Buffer.concat(chunks).toString('utf8');
        responseBody = text;
        if (httpStatus === 200) {
            try {
                const parsed = JSON.parse(text);
                if (parsed.success === true && (parsed.status === 'APPLIED' || parsed.status === 'VERIFIED_DUPLICATE')) {
                    outcome = 'SUCCESS';
                }
                else {
                    outcome = 'RETRY';
                    errorMessage = 'Unexpected 200 response body format';
                }
            }
            catch (e) {
                outcome = 'RETRY';
                errorMessage = 'Unparseable 200 response body';
            }
        }
        else if (httpStatus === 409) {
            try {
                const parsed = JSON.parse(text);
                if (parsed.success === true && parsed.status === 'SUPERSEDED') {
                    outcome = 'SUCCESS';
                }
                else {
                    outcome = 'DEAD';
                }
            }
            catch (e) {
                outcome = 'DEAD';
            }
        }
        else if (httpStatus === 422) {
            outcome = 'DEAD';
        }
        else if (httpStatus >= 400 && httpStatus < 500) {
            if ([401, 408, 425, 429].includes(httpStatus))
                outcome = 'RETRY';
            else
                outcome = 'DEAD';
        }
        else if (httpStatus >= 500) {
            outcome = 'RETRY';
        }
    }
    catch (err) {
        outcome = 'RETRY';
        errorMessage = err.message || 'Unknown network error';
    }
    finally {
        clearTimeout(timeoutId);
    }
    const executionMs = Date.now() - startTime;
    try {
        await db_1.pool.query('SELECT integration.finalize_delivery($1, $2, $3, $4, $5, $6, $7, $8, $9)', [
            eventId,
            job.endpoint_id,
            job.lease_token,
            outcome,
            httpStatus || null,
            responseBody || null,
            errorMessage || null,
            retryAfter,
            executionMs
        ]);
        console.log(`Job ${eventId} finalized as ${outcome}`);
        return { outcome, httpStatus, responseBody };
    }
    catch (e) {
        console.error(`Finalize failed for ${eventId}`, e);
        throw e;
    }
}

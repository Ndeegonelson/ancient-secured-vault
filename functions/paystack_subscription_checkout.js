const crypto = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");

const DEFAULT_PLAN = "premium";
const DEFAULT_SUCCESS_PATH = "?subscription=paystack-success";
const DEFAULT_PAYMENT_METHOD = "paystack";
const PAYSTACK_INITIALIZE_URL = "https://api.paystack.co/transaction/initialize";
const PAYSTACK_VERIFY_URL = "https://api.paystack.co/transaction/verify";

function createPaystackCheckoutSessionHandler({
  firestore,
  verifyAuthToken,
  fetchImpl = fetch,
  getSecretKey = paystackSecretKey,
  getAmountSubunits = paystackPremiumAmountSubunits,
  getCurrency = paystackPremiumCurrency,
  getAppBaseUrl = requestAppBaseUrl,
} = {}) {
  if (!firestore) throw new TypeError("Firestore is required.");

  return async (request, response) => {
    try {
      applyCors(request, response);
      if (request.method === "OPTIONS") {
        response.status(204).send("");
        return;
      }
      requireMethod(request, "POST");

      const user = await requireFirebaseUser(request, verifyAuthToken);
      const secretKey = readRequiredText(
          getSecretKey(),
          "Paystack secret key is not configured.",
      );
      const amount = readRequiredAmountSubunits(getAmountSubunits());
      const currency = cleanText(getCurrency()).toUpperCase() || "GHS";
      const input = readRequestData(request);
      const appBaseUrl = normalizeBaseUrl(getAppBaseUrl(request));
      const requestReference = await createSubscriptionRequest({
        firestore,
        user,
        input,
      });

      const callbackUrl =
        input.successUrl || `${appBaseUrl}${DEFAULT_SUCCESS_PATH}`;
      const paystackResponse = await postPaystackJson({
        fetchImpl,
        secretKey,
        url: PAYSTACK_INITIALIZE_URL,
        body: {
          email: user.email,
          amount,
          currency,
          callback_url: callbackUrl,
          metadata: checkoutMetadata({requestReference, user}),
        },
      });
      const data = paystackResponse.data || {};
      const checkoutUrl = cleanText(data.authorization_url);
      const reference = cleanText(data.reference);
      if (!checkoutUrl || !reference) {
        throw httpError(502, "Paystack checkout response is invalid.");
      }

      await requestReference.ref.update({
        paymentReference: reference,
        paystackReference: reference,
        paymentStatus: "pending_confirmation",
        updatedAt: FieldValue.serverTimestamp(),
      });

      response.json({
        requestId: requestReference.id,
        checkoutUrl,
      });
    } catch (error) {
      sendHttpError(response, error);
    }
  };
}

function createPaystackWebhookHandler({
  firestore,
  fetchImpl = fetch,
  getSecretKey = paystackSecretKey,
} = {}) {
  if (!firestore) throw new TypeError("Firestore is required.");

  return async (request, response) => {
    try {
      requireMethod(request, "POST");
      const secretKey = readRequiredText(
          getSecretKey(),
          "Paystack secret key is not configured.",
      );
      verifyPaystackSignature({request, secretKey});
      const event = request.body || {};

      await handlePaystackEvent({firestore, event, fetchImpl, secretKey});
      response.json({received: true});
    } catch (error) {
      sendHttpError(response, error);
    }
  };
}

async function handlePaystackEvent({firestore, event, fetchImpl = fetch, secretKey}) {
  if (!event || event.event !== "charge.success") return;

  const data = event.data || {};
  const reference = cleanText(data.reference);
  if (!reference) return;

  const eventRecord = await startPaymentWebhookEvent({
    firestore,
    provider: DEFAULT_PAYMENT_METHOD,
    eventId: paystackEventId(event),
    eventType: event.event,
  });
  if (!eventRecord.shouldProcess) return;

  try {
    const verified = await verifyPaystackTransaction({
      fetchImpl,
      secretKey,
      reference,
    });
    if (cleanText(verified.status).toLowerCase() !== "success") {
      await finishPaymentWebhookEvent({
        eventRef: eventRecord.ref,
        status: "processed",
        result: {
          ignored: true,
          reason: "verified_transaction_not_successful",
          paymentReference: reference,
        },
      });
      return;
    }

    const result = await approveSuccessfulPaystackCharge({
      firestore,
      charge: verified,
    });
    await finishPaymentWebhookEvent({
      eventRef: eventRecord.ref,
      status: "processed",
      result,
    });
  } catch (error) {
    await finishPaymentWebhookEvent({
      eventRef: eventRecord.ref,
      status: "failed",
      result: {errorMessage: cleanText(error && error.message)},
    });
    throw error;
  }
}

async function approveSuccessfulPaystackCharge({firestore, charge}) {
  const metadata = charge.metadata || {};
  const requestId = cleanText(metadata.subscriptionRequestId);
  const customer = charge.customer || {};
  const userEmail = cleanEmail(metadata.userEmail || customer.email);
  if (!requestId || !userEmail) {
    return {ignored: true, reason: "missing_charge_metadata"};
  }

  const paidAt = cleanText(charge.paid_at || charge.paidAt);
  const expiresAt = paidAt ?
    new Date(Date.parse(paidAt) + 30 * 24 * 60 * 60 * 1000) :
    null;

  await firestore
      .collection("user_subscription_requests")
      .doc(requestId)
      .set({
        userEmail,
        requestedPlan: cleanText(metadata.requestedPlan) || DEFAULT_PLAN,
        paymentMethod: DEFAULT_PAYMENT_METHOD,
        paymentStatus: "confirmed",
        paymentReference: cleanText(charge.reference),
        paystackReference: cleanText(charge.reference),
        status: "approved",
        source: "paystack_checkout",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

  await firestore.collection("users").doc(userEmail).set({
    email: userEmail,
    role: "reader",
    accessLevel: "premium",
    subscriptionStatus: "active",
    subscriptionProvider: DEFAULT_PAYMENT_METHOD,
    paystackCustomerId: cleanText(customer.customer_code || customer.id),
    paystackReference: cleanText(charge.reference),
    ...(expiresAt && Number.isFinite(expiresAt.getTime()) ?
      {subscriptionExpiresAt: expiresAt} :
      {}),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    requestId,
    userEmail,
    paymentReference: cleanText(charge.reference),
  };
}

async function startPaymentWebhookEvent({
  firestore,
  provider,
  eventId,
  eventType,
}) {
  const safeEventId = paymentWebhookEventId({provider, eventId, eventType});
  const ref = firestore.collection("payment_webhook_events").doc(safeEventId);
  const snapshot = await ref.get();
  const data = snapshot.exists ? snapshot.data() : {};
  if (data && data.status === "processed") {
    return {shouldProcess: false, ref};
  }

  await ref.set({
    provider,
    eventId: cleanText(eventId),
    eventType: cleanText(eventType),
    status: "processing",
    receivedAt: data && data.receivedAt ?
      data.receivedAt :
      FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {shouldProcess: true, ref};
}

async function finishPaymentWebhookEvent({eventRef, status, result = {}}) {
  await eventRef.set({
    status,
    ...cleanResultPayload(result),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

function cleanResultPayload(result) {
  const payload = {};
  for (const [key, value] of Object.entries(result || {})) {
    if (value === undefined || value === null || value === "") continue;
    payload[key] = value;
  }
  return payload;
}

function paystackEventId(event) {
  const data = event && event.data;
  return cleanText(data && (data.id || data.reference)) ||
    cleanText(event && event.event);
}

function paymentWebhookEventId({provider, eventId, eventType}) {
  const rawId = cleanText(eventId) ||
    `${cleanText(eventType) || "event"}_${Date.now()}`;
  return `${provider}_${rawId}`
      .replace(/[^A-Za-z0-9_-]/g, "_")
      .slice(0, 240);
}

async function verifyPaystackTransaction({fetchImpl, secretKey, reference}) {
  const response = await fetchImpl(
      `${PAYSTACK_VERIFY_URL}/${encodeURIComponent(reference)}`,
      {
        method: "GET",
        headers: {
          "Authorization": `Bearer ${secretKey}`,
          "Accept": "application/json",
        },
      },
  );
  const body = await response.json();
  if (!response.ok || body.status !== true) {
    throw httpError(
        response.status || 502,
        body.message || "Paystack transaction could not be verified.",
    );
  }

  return body.data || {};
}

async function postPaystackJson({fetchImpl, secretKey, url, body}) {
  const response = await fetchImpl(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${secretKey}`,
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: JSON.stringify(body),
  });
  const decoded = await response.json();
  if (!response.ok || decoded.status !== true) {
    throw httpError(
        response.status || 502,
        decoded.message || "Paystack checkout could not start.",
    );
  }

  return decoded;
}

function verifyPaystackSignature({request, secretKey}) {
  const signature = cleanText(request.get("x-paystack-signature"));
  if (!signature) throw httpError(401, "Paystack signature is missing.");

  const payload = request.rawBody ?
    Buffer.from(request.rawBody) :
    Buffer.from(JSON.stringify(request.body || {}));
  const expected = crypto
      .createHmac("sha512", secretKey)
      .update(payload)
      .digest("hex");

  if (!safeCompare(signature, expected)) {
    throw httpError(401, "Paystack signature is invalid.");
  }
}

function safeCompare(left, right) {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  if (leftBuffer.length !== rightBuffer.length) return false;

  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function checkoutMetadata({requestReference, user}) {
  return {
    subscriptionRequestId: requestReference.id,
    userEmail: user.email,
    requestedPlan: DEFAULT_PLAN,
    source: "paystack_checkout",
  };
}

async function createSubscriptionRequest({firestore, user, input}) {
  const reference = firestore.collection("user_subscription_requests").doc();
  await reference.set({
    userEmail: user.email,
    requestedPlan: DEFAULT_PLAN,
    paymentMethod: DEFAULT_PAYMENT_METHOD,
    paymentStatus: "awaiting_payment",
    message: cleanText(input.message),
    source: "paystack_checkout",
    status: "open",
    createdAt: FieldValue.serverTimestamp(),
  });

  return {id: reference.id, ref: reference};
}

async function requireFirebaseUser(request, verifyAuthToken) {
  const authorization = request.get("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw httpError(401, "Sign in before starting Paystack checkout.");
  }

  const verifier = verifyAuthToken || defaultVerifyAuthToken;
  const decoded = await verifier(match[1]);
  const email = cleanEmail(decoded && decoded.email);
  if (!email) {
    throw httpError(403, "A verified email is required for checkout.");
  }

  return {
    uid: cleanText(decoded.uid),
    email,
  };
}

function defaultVerifyAuthToken(token) {
  return require("firebase-admin/auth").getAuth().verifyIdToken(token);
}

function readRequestData(request) {
  const body = request.body && request.body.data ? request.body.data : request.body;
  if (!body || typeof body !== "object") return {};

  return {
    message: cleanText(body.message),
    successUrl: cleanUrl(body.successUrl),
  };
}

function cleanUrl(value) {
  const text = cleanText(value);
  if (!text) return "";

  const parsed = new URL(text);
  if (parsed.protocol !== "https:" &&
      parsed.hostname !== "localhost" &&
      parsed.hostname !== "127.0.0.1") {
    throw httpError(400, "Checkout return URL must be secure.");
  }

  return parsed.toString();
}

function requestAppBaseUrl(request) {
  const configured = cleanText(process.env.APP_BASE_URL);
  if (configured) return configured;

  const origin = cleanText(request.get("origin"));
  if (origin) return origin;

  return "http://localhost:63114";
}

function paystackSecretKey() {
  return cleanText(process.env.PAYSTACK_SECRET_KEY);
}

function paystackPremiumAmountSubunits() {
  return cleanText(process.env.PAYSTACK_PREMIUM_AMOUNT_SUBUNITS);
}

function paystackPremiumCurrency() {
  return cleanText(process.env.PAYSTACK_PREMIUM_CURRENCY || "GHS");
}

function normalizeBaseUrl(value) {
  const parsed = new URL(cleanText(value));
  parsed.search = "";
  parsed.hash = "";
  return parsed.toString().replace(/\/$/, "");
}

function requireMethod(request, method) {
  if (request.method !== method) {
    throw httpError(405, `Paystack checkout requires ${method}.`);
  }
}

function applyCors(request, response) {
  const origin = request.get("origin") || "*";
  response.set("Access-Control-Allow-Origin", origin);
  response.set("Vary", "Origin");
  response.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
}

function sendHttpError(response, error) {
  response.status(error && error.status ? error.status : 500).json({
    error: {
      message: error && error.message ?
        error.message :
        "Paystack checkout is temporarily unavailable.",
    },
  });
}

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function readRequiredText(value, message) {
  const text = cleanText(value);
  if (!text) throw httpError(500, message);
  return text;
}

function readRequiredAmountSubunits(value) {
  const amount = Number.parseInt(cleanText(value), 10);
  if (!Number.isFinite(amount) || amount < 100) {
    throw httpError(
        500,
        "Paystack premium amount is not configured.",
    );
  }

  return amount;
}

function cleanText(value) {
  return value == null ? "" : value.toString().trim();
}

function cleanEmail(value) {
  return cleanText(value).toLowerCase();
}

module.exports = {
  createPaystackCheckoutSessionHandler,
  createPaystackWebhookHandler,
  handlePaystackEvent,
};

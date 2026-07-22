const {FieldValue} = require("firebase-admin/firestore");

const DEFAULT_PLAN = "premium";
const DEFAULT_SUCCESS_PATH = "/?subscription=stripe-success";
const DEFAULT_CANCEL_PATH = "/?subscription=stripe-cancelled";
const DEFAULT_APP_BASE_URL = "https://vault.ancientsociety.tech";
const PREMIUM_ANNUAL_AMOUNT_SUBUNITS = 12000;
const PREMIUM_ANNUAL_CURRENCY = "usd";

function createStripeCheckoutSessionHandler({
  firestore,
  verifyAuthToken,
  stripeClientFactory = defaultStripeClientFactory,
  getPriceId = stripePremiumPriceId,
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
      await requireSubscriptionCanStart({firestore, user});
      const priceId = readRequiredText(
          getPriceId(),
          "Stripe premium price id is not configured.",
      );
      const stripe = stripeClientFactory();
      const price = await stripe.prices.retrieve(priceId);
      validateStripePremiumPrice(price);
      const input = readRequestData(request);
      const appBaseUrl = normalizeBaseUrl(getAppBaseUrl(request));
      const requestReference = await createSubscriptionRequest({
        firestore,
        user,
        input,
      });

      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        customer_email: user.email,
        client_reference_id: requestReference.id,
        line_items: [{price: priceId, quantity: 1}],
        success_url: `${appBaseUrl}${DEFAULT_SUCCESS_PATH}`,
        cancel_url: `${appBaseUrl}${DEFAULT_CANCEL_PATH}`,
        metadata: checkoutMetadata({requestReference, user}),
        subscription_data: {
          metadata: checkoutMetadata({requestReference, user}),
        },
      });

      await requestReference.ref.update({
        paymentReference: session.id,
        stripeCheckoutSessionId: session.id,
        paymentStatus: "pending_confirmation",
        updatedAt: FieldValue.serverTimestamp(),
      });

      response.json({
        requestId: requestReference.id,
        checkoutUrl: session.url,
      });
    } catch (error) {
      sendHttpError(response, error);
    }
  };
}

function validateStripePremiumPrice(price) {
  const recurring = price && price.recurring;
  const intervalCount = Number(recurring && recurring.interval_count || 1);
  const isAnnualPremiumPrice = Boolean(
      price &&
      price.active !== false &&
      price.unit_amount === PREMIUM_ANNUAL_AMOUNT_SUBUNITS &&
      cleanText(price.currency).toLowerCase() === PREMIUM_ANNUAL_CURRENCY &&
      recurring &&
      recurring.interval === "year" &&
      intervalCount === 1,
  );

  if (!isAnnualPremiumPrice) {
    throw httpError(
        500,
        "Stripe premium price must be an active USD 120 yearly price.",
    );
  }
}

function createStripeWebhookHandler({
  firestore,
  stripeClientFactory = defaultStripeClientFactory,
  getWebhookSecret = () => process.env.STRIPE_WEBHOOK_SECRET,
} = {}) {
  if (!firestore) throw new TypeError("Firestore is required.");

  return async (request, response) => {
    try {
      requireMethod(request, "POST");
      const stripe = stripeClientFactory();
      const webhookSecret = readRequiredText(
          getWebhookSecret(),
          "Stripe webhook secret is not configured.",
      );
      const signature = request.get("stripe-signature");
      const event = stripe.webhooks.constructEvent(
          request.rawBody || request.body,
          signature,
          webhookSecret,
      );

      await handleStripeEvent({firestore, event});
      response.json({received: true});
    } catch (error) {
      sendHttpError(response, error);
    }
  };
}

function createStripeBillingPortalSessionHandler({
  firestore,
  verifyAuthToken,
  stripeClientFactory = defaultStripeClientFactory,
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
      const customerId = await loadStripeCustomerId({firestore, user});
      const stripe = stripeClientFactory();
      const appBaseUrl = normalizeBaseUrl(getAppBaseUrl(request));
      const session = await stripe.billingPortal.sessions.create({
        customer: customerId,
        return_url: appBaseUrl,
      });

      response.json({portalUrl: session.url});
    } catch (error) {
      sendHttpError(response, error);
    }
  };
}

async function handleStripeEvent({firestore, event}) {
  if (!event || !event.type) return;

  const eventRecord = await startPaymentWebhookEvent({
    firestore,
    provider: "stripe",
    eventId: stripeEventId(event),
    eventType: event.type,
  });
  if (!eventRecord.shouldProcess) return;

  try {
    const result = await dispatchStripeEvent({firestore, event});
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

async function dispatchStripeEvent({firestore, event}) {
  if (event.type === "checkout.session.completed") {
    return approveCompletedCheckoutSession({
      firestore,
      session: event.data && event.data.object,
    });
  }

  if (event.type === "checkout.session.expired") {
    return markCheckoutSessionFailed({
      firestore,
      session: event.data && event.data.object,
    });
  }

  if (event.type === "customer.subscription.updated" ||
      event.type === "customer.subscription.deleted") {
    return syncStripeSubscriptionAccess({
      firestore,
      subscription: event.data && event.data.object,
      deleted: event.type === "customer.subscription.deleted",
    });
  }

  if (event.type === "invoice.payment_failed") {
    return syncStripeInvoiceSubscriptionAccess({
      firestore,
      invoice: event.data && event.data.object,
      paymentStatus: "failed",
    });
  }

  if (event.type === "invoice.paid") {
    return syncStripeInvoiceSubscriptionAccess({
      firestore,
      invoice: event.data && event.data.object,
      paymentStatus: "confirmed",
    });
  }

  return {ignored: true, reason: "unsupported_event_type"};
}

function checkoutMetadata({requestReference, user}) {
  return {
    subscriptionRequestId: requestReference.id,
    userEmail: user.email,
    requestedPlan: DEFAULT_PLAN,
    source: "stripe_checkout",
  };
}

async function approveCompletedCheckoutSession({firestore, session}) {
  const metadata = (session && session.metadata) || {};
  const requestId = cleanText(metadata.subscriptionRequestId);
  const userEmail = cleanEmail(metadata.userEmail || session.customer_email);
  if (!requestId || !userEmail) {
    return {ignored: true, reason: "missing_checkout_metadata"};
  }

  const requestRef = firestore
      .collection("user_subscription_requests")
      .doc(requestId);
  await requestRef.set({
    userEmail,
    requestedPlan: cleanText(metadata.requestedPlan) || DEFAULT_PLAN,
    paymentMethod: "stripe",
    paymentStatus: "confirmed",
    paymentReference: cleanText(session.id),
    status: "approved",
    source: "stripe_checkout",
    stripeCustomerId: cleanText(session.customer),
    stripeSubscriptionId: cleanText(session.subscription),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  await firestore.collection("users").doc(userEmail).set({
    email: userEmail,
    role: "reader",
    accessLevel: "premium",
    subscriptionStatus: "active",
    subscriptionProvider: "stripe",
    stripeCustomerId: cleanText(session.customer),
    stripeSubscriptionId: cleanText(session.subscription),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    requestId,
    userEmail,
    paymentReference: cleanText(session.id),
    subscriptionId: cleanText(session.subscription),
  };
}

async function markCheckoutSessionFailed({firestore, session}) {
  const metadata = (session && session.metadata) || {};
  const requestId = cleanText(metadata.subscriptionRequestId);
  if (!requestId) return {ignored: true, reason: "missing_checkout_request"};

  await firestore
      .collection("user_subscription_requests")
      .doc(requestId)
      .set({
        paymentStatus: "failed",
        paymentReference: cleanText(session.id),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

  return {
    requestId,
    paymentReference: cleanText(session && session.id),
    paymentStatus: "failed",
  };
}

async function syncStripeInvoiceSubscriptionAccess({
  firestore,
  invoice,
  paymentStatus,
}) {
  if (!invoice) return;

  const subscriptionId = cleanText(invoice.subscription);
  if (!subscriptionId) {
    return {ignored: true, reason: "missing_invoice_subscription"};
  }

  const userEmail = await resolveStripeSubscriptionUserEmail({
    firestore,
    subscription: {
      id: subscriptionId,
      customer: invoice.customer,
      metadata: invoice.subscription_details &&
        invoice.subscription_details.metadata,
    },
  });
  if (!userEmail) {
    return {ignored: true, reason: "unknown_stripe_subscription_user"};
  }

  await firestore.collection("users").doc(userEmail).set({
    stripeLastInvoiceId: cleanText(invoice.id),
    stripeLastPaymentStatus: paymentStatus,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    userEmail,
    invoiceId: cleanText(invoice.id),
    subscriptionId,
    paymentStatus,
  };
}

async function syncStripeSubscriptionAccess({
  firestore,
  subscription,
  deleted = false,
}) {
  if (!subscription) return {ignored: true, reason: "missing_subscription"};

  const userEmail = await resolveStripeSubscriptionUserEmail({
    firestore,
    subscription,
  });
  if (!userEmail) {
    return {ignored: true, reason: "unknown_stripe_subscription_user"};
  }

  const mappedAccess = stripeSubscriptionAccessUpdate({
    status: deleted ? "canceled" : subscription.status,
  });
  const subscriptionExpiresAt = stripeTimestampToDate(
      subscription.current_period_end,
  );

  await firestore.collection("users").doc(userEmail).set({
    email: userEmail,
    role: "reader",
    ...mappedAccess,
    subscriptionProvider: "stripe",
    stripeCustomerId: cleanText(subscription.customer),
    stripeSubscriptionId: cleanText(subscription.id),
    stripeSubscriptionStatus: cleanText(subscription.status),
    ...(subscriptionExpiresAt ? {subscriptionExpiresAt} : {}),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    userEmail,
    subscriptionId: cleanText(subscription.id),
    subscriptionStatus: deleted ? "canceled" : cleanText(subscription.status),
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

function stripeEventId(event) {
  const object = event && event.data && event.data.object;
  return cleanText(event && event.id) ||
    [
      cleanText(event && event.type),
      cleanText(object && (object.id || object.subscription)),
    ].filter(Boolean).join("_");
}

function paymentWebhookEventId({provider, eventId, eventType}) {
  const rawId = cleanText(eventId) ||
    `${cleanText(eventType) || "event"}_${Date.now()}`;
  return `${provider}_${rawId}`
      .replace(/[^A-Za-z0-9_-]/g, "_")
      .slice(0, 240);
}

async function resolveStripeSubscriptionUserEmail({firestore, subscription}) {
  const metadata = (subscription && subscription.metadata) || {};
  const metadataEmail = cleanEmail(metadata.userEmail);
  if (metadataEmail) return metadataEmail;

  const subscriptionId = cleanText(subscription && subscription.id);
  if (subscriptionId) {
    const subscriptionEmail = await findUserEmailByStripeField({
      firestore,
      field: "stripeSubscriptionId",
      value: subscriptionId,
    });
    if (subscriptionEmail) return subscriptionEmail;
  }

  const customerId = cleanText(subscription && subscription.customer);
  if (customerId) {
    return findUserEmailByStripeField({
      firestore,
      field: "stripeCustomerId",
      value: customerId,
    });
  }

  return "";
}

async function findUserEmailByStripeField({firestore, field, value}) {
  const snapshot = await firestore
      .collection("users")
      .where(field, "==", value)
      .limit(1)
      .get();
  const doc = snapshot.docs && snapshot.docs[0];
  return doc ? cleanEmail(doc.id) : "";
}

function stripeSubscriptionAccessUpdate({status}) {
  switch (cleanText(status)) {
    case "active":
      return {
        accessLevel: "premium",
        subscriptionStatus: "active",
      };
    case "trialing":
      return {
        accessLevel: "premium",
        subscriptionStatus: "trial",
      };
    case "past_due":
    case "incomplete":
      return {
        accessLevel: "free",
        subscriptionStatus: "pending",
      };
    case "unpaid":
    case "incomplete_expired":
      return {
        accessLevel: "free",
        subscriptionStatus: "expired",
      };
    case "canceled":
      return {
        accessLevel: "free",
        subscriptionStatus: "cancelled",
      };
    case "paused":
      return {
        accessLevel: "free",
        subscriptionStatus: "inactive",
      };
    default:
      return {
        accessLevel: "free",
        subscriptionStatus: "inactive",
      };
  }
}

function stripeTimestampToDate(value) {
  const seconds = Number(value);
  if (!Number.isFinite(seconds) || seconds <= 0) return null;
  return new Date(seconds * 1000);
}

async function createSubscriptionRequest({firestore, user, input}) {
  const reference = firestore.collection("user_subscription_requests").doc();
  await reference.set({
    userEmail: user.email,
    requestedPlan: DEFAULT_PLAN,
    paymentMethod: "stripe",
    paymentStatus: "awaiting_payment",
    message: cleanText(input.message),
    source: "stripe_checkout",
    status: "open",
    createdAt: FieldValue.serverTimestamp(),
  });

  return {id: reference.id, ref: reference};
}

async function loadStripeCustomerId({firestore, user}) {
  const snapshot = await firestore.collection("users").doc(user.email).get();
  const data = snapshot.exists ? snapshot.data() : {};
  const customerId = cleanText(data && data.stripeCustomerId);

  if (!customerId) {
    throw httpError(
        400,
        "Stripe billing management is available after a completed Stripe subscription.",
    );
  }

  return customerId;
}

async function requireSubscriptionCanStart({firestore, user}) {
  const snapshot = await firestore.collection("users").doc(user.email).get();
  const data = snapshot.exists ? snapshot.data() : {};

  if (hasCurrentPremiumAccess(data)) {
    throw httpError(
        409,
        "Premium access is already active. Renewals open after the current access expires.",
    );
  }
}

function hasCurrentPremiumAccess(data) {
  if (!data || typeof data !== "object") return false;

  const expiresAt = readDate(data.subscriptionExpiresAt);
  if (expiresAt && expiresAt <= new Date()) return false;

  const role = cleanText(data.role).toLowerCase();
  const accessLevel = cleanText(data.accessLevel).toLowerCase();
  const status = cleanText(data.subscriptionStatus).toLowerCase();

  return role === "admin" ||
    accessLevel === "premium" ||
    status === "active" ||
    status === "trial";
}

function readDate(value) {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value.seconds === "number") return new Date(value.seconds * 1000);

  const parsed = new Date(cleanText(value));
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

async function requireFirebaseUser(request, verifyAuthToken) {
  const authorization = request.get("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw httpError(401, "Sign in before starting checkout.");
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

function defaultStripeClientFactory() {
  const secretKey = readRequiredText(
      stripeSecretKey(),
      "Stripe secret key is not configured.",
  );
  const Stripe = require("stripe");
  return new Stripe(secretKey);
}

function readRequestData(request) {
  const body = request.body && request.body.data ? request.body.data : request.body;
  if (!body || typeof body !== "object") return {};

  return {
    message: cleanText(body.message),
  };
}

function requestAppBaseUrl(request) {
  const configured = cleanText(
      process.env.APP_BASE_URL ||
      firebaseRuntimeConfig().app?.base_url,
  );
  if (configured) return configured;

  return DEFAULT_APP_BASE_URL;
}

function stripePremiumPriceId() {
  return cleanText(
      process.env.STRIPE_PREMIUM_PRICE_ID ||
      firebaseRuntimeConfig().stripe?.premium_price_id,
  );
}

function stripeSecretKey() {
  return cleanText(
      process.env.STRIPE_SECRET_KEY ||
      firebaseRuntimeConfig().stripe?.secret_key,
  );
}

function firebaseRuntimeConfig() {
  try {
    const functions = require("firebase-functions");
    return functions.config ? functions.config() : {};
  } catch (_) {
    return {};
  }
}

function normalizeBaseUrl(value) {
  const parsed = new URL(cleanText(value));
  parsed.search = "";
  parsed.hash = "";
  return parsed.toString().replace(/\/$/, "");
}

function requireMethod(request, method) {
  if (request.method !== method) {
    throw httpError(405, `Stripe checkout requires ${method}.`);
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
        "Stripe checkout is temporarily unavailable.",
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

function cleanText(value) {
  return value == null ? "" : value.toString().trim();
}

function cleanEmail(value) {
  return cleanText(value).toLowerCase();
}

module.exports = {
  createStripeCheckoutSessionHandler,
  createStripeBillingPortalSessionHandler,
  createStripeWebhookHandler,
  handleStripeEvent,
  validateStripePremiumPrice,
};

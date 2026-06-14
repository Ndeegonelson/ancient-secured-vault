const {setGlobalOptions} = require("firebase-functions");
const {onCall, onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  createNarrationCatalogHandler,
  createNarrationSynthesisHandler,
} = require("./narration_gateway");
const {
  createNarrationUsageQuota,
} = require("./narration_usage_quota");
const {
  createNarrationProviderRegistry,
} = require("./narration_provider_registry");
const {
  createDemoCloudNarrationProvider,
} = require("./narration_demo_provider");
const {
  createGoogleCloudTextToSpeechProvider,
} = require("./narration_google_tts_provider");
const {
  createStripeBillingPortalSessionHandler,
  createStripeCheckoutSessionHandler,
  createStripeWebhookHandler,
} = require("./stripe_subscription_checkout");
const {
  createPaystackCheckoutSessionHandler,
  createPaystackWebhookHandler,
} = require("./paystack_subscription_checkout");
const {
  createExpireSubscriptionsHandler,
} = require("./subscription_expiry_maintenance");

initializeApp();
const firestore = getFirestore();
const narrationUsageQuota = createNarrationUsageQuota({firestore});
const narrationProviderRegistry = createNarrationProviderRegistry({
  providers: [
    createGoogleCloudTextToSpeechProvider(),
  ],
});

setGlobalOptions({maxInstances: 10});

async function loadUserAccess({uid, email}) {
  const uidSnapshot = await firestore.collection("users").doc(uid).get();
  if (uidSnapshot.exists) return uidSnapshot.data();

  if (email) {
    const emailSnapshot = await firestore.collection("users").doc(email).get();
    if (emailSnapshot.exists) return emailSnapshot.data();
  }

  return null;
}

exports.cloudNarrationCatalog = onCall(
    {
      cors: true,
      enforceAppCheck: false,
      maxInstances: 5,
      timeoutSeconds: 30,
    },
    createNarrationCatalogHandler({
      loadUserAccess,
      loadCatalog: narrationProviderRegistry.loadCatalog,
    }),
);

exports.synthesizeCloudNarration = onCall(
    {
      cors: true,
      enforceAppCheck: false,
      consumeAppCheckToken: false,
      maxInstances: 5,
      timeoutSeconds: 120,
    },
    createNarrationSynthesisHandler({
      loadUserAccess,
      authorizeVoice: narrationProviderRegistry.authorizeVoice,
      consumeUsage: narrationUsageQuota.consume,
      synthesize: narrationProviderRegistry.synthesize,
    }),
);

const narrationHttpOptions = {
  cors: true,
  maxInstances: 5,
  timeoutSeconds: 120,
};

exports.cloudNarrationCatalogHttp = onRequest(
    narrationHttpOptions,
    async (request, response) => {
      try {
        await requireNarrationHttpAccess(request);
        const voices = await narrationProviderRegistry.loadCatalog();
        response.json({
          status: voices.length === 0 ? "notConfigured" : "ready",
          voices,
        });
      } catch (error) {
        sendNarrationHttpError(response, error);
      }
    },
);

exports.synthesizeCloudNarrationHttp = onRequest(
    narrationHttpOptions,
    async (request, response) => {
      try {
        await requireNarrationHttpAccess(request);
        const input = request.body && request.body.data ?
          request.body.data :
          request.body;
        const result = await narrationProviderRegistry.synthesize(input);
        response.json(result);
      } catch (error) {
        sendNarrationHttpError(response, error);
      }
    },
);

exports.createStripeCheckoutSession = onRequest(
    {
      cors: true,
      maxInstances: 5,
      timeoutSeconds: 30,
      secrets: ["STRIPE_SECRET_KEY", "STRIPE_PREMIUM_PRICE_ID", "APP_BASE_URL"],
    },
    createStripeCheckoutSessionHandler({firestore}),
);

exports.createStripeBillingPortalSession = onRequest(
    {
      cors: true,
      maxInstances: 5,
      timeoutSeconds: 30,
      secrets: ["STRIPE_SECRET_KEY", "APP_BASE_URL"],
    },
    createStripeBillingPortalSessionHandler({firestore}),
);

exports.stripeWebhook = onRequest(
    {
      cors: false,
      maxInstances: 5,
      timeoutSeconds: 30,
      secrets: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"],
    },
    createStripeWebhookHandler({firestore}),
);

exports.createPaystackCheckoutSession = onRequest(
    {
      cors: true,
      maxInstances: 5,
      timeoutSeconds: 30,
      secrets: [
        "PAYSTACK_SECRET_KEY",
        "PAYSTACK_PREMIUM_AMOUNT_SUBUNITS",
        "PAYSTACK_PREMIUM_CURRENCY",
        "APP_BASE_URL",
      ],
    },
    createPaystackCheckoutSessionHandler({firestore}),
);

exports.paystackWebhook = onRequest(
    {
      cors: false,
      maxInstances: 5,
      timeoutSeconds: 30,
      secrets: ["PAYSTACK_SECRET_KEY"],
    },
    createPaystackWebhookHandler({firestore}),
);

exports.expireAdminManagedSubscriptions = onSchedule(
    {
      schedule: "every 24 hours",
      timeZone: "Africa/Accra",
      maxInstances: 1,
      timeoutSeconds: 120,
    },
    createExpireSubscriptionsHandler({firestore}),
);

async function requireNarrationHttpAccess(request) {
  if (request.method === "OPTIONS") return;
  if (request.method !== "POST") {
    throw narrationHttpError(405, "Cloud narration requires POST.");
  }

  const authorization = request.get("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw narrationHttpError(401, "Sign in before using cloud narration.");
  }

  const decodedToken = await require("firebase-admin/auth")
      .getAuth()
      .verifyIdToken(match[1]);
  const access = await loadUserAccess({
    uid: decodedToken.uid,
    email: decodedToken.email,
  });

  if (!access ||
      (access.role !== "admin" && access.subscriptionStatus !== "active")) {
    throw narrationHttpError(
        403,
        "Premium narration is required for cloud and customized voices.",
    );
  }
}

function narrationHttpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function sendNarrationHttpError(response, error) {
  response.status(error && error.status ? error.status : 500).json({
    error: {
      message: error && error.message ?
        error.message :
        "Cloud narration is temporarily unavailable.",
    },
  });
}

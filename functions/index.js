const {setGlobalOptions} = require("firebase-functions");
const {onCall} = require("firebase-functions/v2/https");
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

exports.cloudNarrationCatalogHttp = require("firebase-functions/v2/https")
    .onRequest(narrationHttpOptions, async (request, response) => {
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
    });

exports.synthesizeCloudNarrationHttp = require("firebase-functions/v2/https")
    .onRequest(narrationHttpOptions, async (request, response) => {
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
    });

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

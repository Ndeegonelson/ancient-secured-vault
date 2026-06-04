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

initializeApp();
const firestore = getFirestore();
const narrationUsageQuota = createNarrationUsageQuota({firestore});
const narrationProviderRegistry = createNarrationProviderRegistry({
  providers: [createDemoCloudNarrationProvider()],
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
      enforceAppCheck: true,
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
      enforceAppCheck: true,
      consumeAppCheckToken: true,
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

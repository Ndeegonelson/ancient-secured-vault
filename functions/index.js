const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  createNarrationCatalogHandler,
  createNarrationSynthesisHandler,
} = require("./narration_gateway");

initializeApp();
const firestore = getFirestore();

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

async function loadCloudNarrationCatalog() {
  return [];
}

async function synthesizeCloudNarration() {
  throw new HttpsError(
      "failed-precondition",
      "A protected cloud narration provider has not been configured yet.",
  );
}

exports.cloudNarrationCatalog = onCall(
    {
      enforceAppCheck: true,
      maxInstances: 5,
      timeoutSeconds: 30,
    },
    createNarrationCatalogHandler({
      loadUserAccess,
      loadCatalog: loadCloudNarrationCatalog,
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
      synthesize: synthesizeCloudNarration,
    }),
);

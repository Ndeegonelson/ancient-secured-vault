const fs = require("fs");
const path = require("path");
const {FieldValue} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {
  Environment,
  SignedDataVerifier,
} = require("@apple/app-store-server-library");

const BUNDLE_ID = "tech.ancientsociety.vault";
const APP_APPLE_ID = 6784325941;
const PREMIUM_YEARLY_PRODUCT_ID =
  "tech.ancientsociety.vault.premium.yearly";

const rootCertificates = [
  "AppleIncRootCertificate.cer",
  "AppleRootCA-G2.cer",
  "AppleRootCA-G3.cer",
].map((name) => fs.readFileSync(path.join(
    __dirname,
    "apple_root_certificates",
    name,
)));

function createVerifier(environment) {
  return new SignedDataVerifier(
      rootCertificates,
      true,
      environment,
      BUNDLE_ID,
      environment === Environment.PRODUCTION ? APP_APPLE_ID : undefined,
  );
}

const verifiers = {
  production: createVerifier(Environment.PRODUCTION),
  sandbox: createVerifier(Environment.SANDBOX),
};

async function verifyAppleTransaction(signedTransaction) {
  const payload = cleanText(signedTransaction);
  if (!payload) throw appleError(400, "Missing signed Apple transaction.");

  let lastError;
  for (const [environment, verifier] of Object.entries(verifiers)) {
    try {
      const transaction = await verifier.verifyAndDecodeTransaction(payload);
      return {environment, transaction};
    } catch (error) {
      lastError = error;
    }
  }

  console.error("Apple transaction verification failed", lastError);
  throw appleError(400, "Apple could not verify this transaction.");
}

async function verifyAppleNotification(signedPayload) {
  const payload = cleanText(signedPayload);
  if (!payload) throw appleError(400, "Missing signed Apple notification.");

  let lastError;
  for (const [environment, verifier] of Object.entries(verifiers)) {
    try {
      const notification = await verifier.verifyAndDecodeNotification(payload);
      return {environment, notification, verifier};
    } catch (error) {
      lastError = error;
    }
  }

  console.error("Apple notification verification failed", lastError);
  throw appleError(400, "Apple could not verify this notification.");
}

function createVerifyApplePurchaseHandler({
  firestore,
  verifyTransaction = verifyAppleTransaction,
  verifyIdToken = (token) => getAuth().verifyIdToken(token),
}) {
  return async (request, response) => {
    try {
      if (request.method !== "POST") {
        throw appleError(405, "Apple purchase verification requires POST.");
      }

      const token = bearerToken(request);
      const user = await verifyIdToken(token);
      const userEmail = cleanEmail(user && user.email);
      if (!userEmail) {
        throw appleError(401, "A verified email account is required.");
      }

      const input = request.body && request.body.data ?
        request.body.data : request.body;
      const verified = await verifyTransaction(
          input && input.signedTransaction,
      );
      const transaction = verified.transaction;
      validatePremiumTransaction(transaction);

      const result = await activateAppleSubscription({
        firestore,
        userEmail,
        environment: verified.environment,
        transaction,
        source: cleanText(input && input.source) || "purchase",
      });
      response.json(result);
    } catch (error) {
      response.status(error && error.status ? error.status : 500).json({
        error: error && error.message ?
          error.message : "Apple purchase verification failed.",
      });
    }
  };
}

function createAppleServerNotificationHandler({
  firestore,
  verifyNotification = verifyAppleNotification,
}) {
  return async (request, response) => {
    try {
      if (request.method !== "POST") {
        throw appleError(405, "Apple notifications require POST.");
      }

      const signedPayload = request.body && request.body.signedPayload;
      const verified = await verifyNotification(signedPayload);
      const signedTransaction = verified.notification &&
        verified.notification.data &&
        verified.notification.data.signedTransactionInfo;
      if (!signedTransaction) {
        response.status(200).json({ignored: true, reason: "no_transaction"});
        return;
      }

      const transaction = await verified.verifier
          .verifyAndDecodeTransaction(signedTransaction);
      if (cleanText(transaction.productId) !== PREMIUM_YEARLY_PRODUCT_ID) {
        response.status(200).json({ignored: true, reason: "other_product"});
        return;
      }

      const result = await syncAppleSubscriptionNotification({
        firestore,
        environment: verified.environment,
        notificationType: cleanText(verified.notification.notificationType),
        subtype: cleanText(verified.notification.subtype),
        transaction,
      });
      response.status(200).json(result);
    } catch (error) {
      response.status(error && error.status ? error.status : 500).json({
        error: error && error.message ?
          error.message : "Apple notification processing failed.",
      });
    }
  };
}

function validatePremiumTransaction(transaction, {now = Date.now()} = {}) {
  if (!transaction ||
      cleanText(transaction.productId) !== PREMIUM_YEARLY_PRODUCT_ID) {
    throw appleError(400, "This Apple product does not unlock premium access.");
  }
  if (transaction.revocationDate) {
    throw appleError(409, "This Apple transaction was revoked or refunded.");
  }

  const expiresAt = readAppleDate(transaction.expiresDate);
  if (!expiresAt || expiresAt.getTime() <= now) {
    throw appleError(409, "This Apple subscription has expired.");
  }
  if (!cleanText(transaction.transactionId) ||
      !cleanText(transaction.originalTransactionId)) {
    throw appleError(400, "Apple transaction identifiers are missing.");
  }
  return expiresAt;
}

async function activateAppleSubscription({
  firestore,
  userEmail,
  environment,
  transaction,
  source,
}) {
  const expiresAt = validatePremiumTransaction(transaction);
  const transactionId = cleanText(transaction.transactionId);
  const originalTransactionId = cleanText(transaction.originalTransactionId);
  const transactionRef = firestore
      .collection("apple_subscription_transactions")
      .doc(transactionId);
  const userRef = firestore.collection("users").doc(userEmail);

  await firestore.runTransaction(async (databaseTransaction) => {
    const existing = await databaseTransaction.get(transactionRef);
    const existingEmail = existing.exists ?
      cleanEmail(existing.data().userEmail) : "";
    if (existingEmail && existingEmail !== userEmail) {
      throw appleError(409, "This Apple purchase belongs to another account.");
    }

    databaseTransaction.set(transactionRef, {
      userEmail,
      productId: PREMIUM_YEARLY_PRODUCT_ID,
      transactionId,
      originalTransactionId,
      environment,
      source,
      expiresAt,
      purchaseDate: readAppleDate(transaction.purchaseDate),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    databaseTransaction.set(userRef, {
      email: userEmail,
      role: "reader",
      accessLevel: "premium",
      subscriptionStatus: "active",
      subscriptionProvider: "app_store",
      subscriptionReference: originalTransactionId,
      subscriptionExpiresAt: expiresAt,
      appleProductId: PREMIUM_YEARLY_PRODUCT_ID,
      appleOriginalTransactionId: originalTransactionId,
      appleLatestTransactionId: transactionId,
      appleEnvironment: environment,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  return {
    accessLevel: "premium",
    subscriptionStatus: "active",
    subscriptionProvider: "app_store",
    productId: PREMIUM_YEARLY_PRODUCT_ID,
    expiresAt: expiresAt.toISOString(),
  };
}

async function syncAppleSubscriptionNotification({
  firestore,
  environment,
  notificationType,
  subtype,
  transaction,
  now = Date.now(),
}) {
  const originalTransactionId = cleanText(transaction.originalTransactionId);
  if (!originalTransactionId) {
    return {ignored: true, reason: "missing_original_transaction"};
  }

  const users = await firestore.collection("users")
      .where("appleOriginalTransactionId", "==", originalTransactionId)
      .limit(1)
      .get();
  const userDoc = users.docs && users.docs[0];
  if (!userDoc) return {ignored: true, reason: "unknown_subscription"};

  const expiresAt = readAppleDate(transaction.expiresDate);
  const revoked = Boolean(transaction.revocationDate) ||
      notificationType === "REFUND" ||
      notificationType === "REVOKE";
  const active = !revoked && expiresAt && expiresAt.getTime() > now;
  const status = active ? "active" : revoked ? "cancelled" : "expired";

  await userDoc.ref.set({
    accessLevel: active ? "premium" : "free",
    subscriptionStatus: status,
    subscriptionProvider: "app_store",
    subscriptionReference: originalTransactionId,
    ...(expiresAt ? {subscriptionExpiresAt: expiresAt} : {}),
    appleLatestTransactionId: cleanText(transaction.transactionId),
    appleEnvironment: environment,
    appleLastNotificationType: notificationType,
    appleLastNotificationSubtype: subtype,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {userEmail: userDoc.id, active, subscriptionStatus: status};
}

function bearerToken(request) {
  const authorization = request.get("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) throw appleError(401, "Sign in before verifying a purchase.");
  return match[1];
}

function readAppleDate(value) {
  const milliseconds = Number(value);
  if (!Number.isFinite(milliseconds) || milliseconds <= 0) return null;
  return new Date(milliseconds);
}

function cleanText(value) {
  return value === undefined || value === null ? "" : String(value).trim();
}

function cleanEmail(value) {
  return cleanText(value).toLowerCase();
}

function appleError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

module.exports = {
  APP_APPLE_ID,
  BUNDLE_ID,
  PREMIUM_YEARLY_PRODUCT_ID,
  activateAppleSubscription,
  createAppleServerNotificationHandler,
  createVerifyApplePurchaseHandler,
  syncAppleSubscriptionNotification,
  validatePremiumTransaction,
  verifyAppleNotification,
  verifyAppleTransaction,
};

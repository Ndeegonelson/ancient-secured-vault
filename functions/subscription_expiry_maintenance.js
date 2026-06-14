const {FieldValue} = require("firebase-admin/firestore");

const DEFAULT_BATCH_SIZE = 100;
const EXPIRABLE_PROVIDERS = new Set([
  "paystack",
  "manual",
  "manual_payment",
  "manual-payment",
  "ancient_coin",
  "ancient-coin",
  "ancientcoin",
]);
const EXPIRABLE_STATUSES = new Set(["active", "trial"]);

function createExpireSubscriptionsHandler({
  firestore,
  now = () => new Date(),
  batchSize = DEFAULT_BATCH_SIZE,
} = {}) {
  if (!firestore) throw new TypeError("Firestore is required.");

  return async () => expireDueSubscriptions({firestore, now: now(), batchSize});
}

async function expireDueSubscriptions({
  firestore,
  now = new Date(),
  batchSize = DEFAULT_BATCH_SIZE,
} = {}) {
  if (!firestore) throw new TypeError("Firestore is required.");

  const safeNow = readDate(now) || new Date();
  const safeBatchSize = Number.isFinite(batchSize) && batchSize > 0 ?
    Math.floor(batchSize) :
    DEFAULT_BATCH_SIZE;
  const snapshot = await firestore
      .collection("users")
      .where("subscriptionExpiresAt", "<=", safeNow)
      .limit(safeBatchSize)
      .get();
  const expiredUsers = [];

  for (const doc of snapshot.docs || []) {
    const data = doc.data ? doc.data() : {};
    if (!shouldExpireUser(data, safeNow)) continue;

    await doc.ref.set({
      accessLevel: "free",
      subscriptionStatus: "expired",
      subscriptionExpiredAt: safeNow,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    await firestore.collection("user_subscription_audit_logs").doc().set({
      targetEmail: cleanEmail(data.email || doc.id),
      changedByEmail: "system",
      previousSubscriptionStatus: cleanText(data.subscriptionStatus),
      nextSubscriptionStatus: "expired",
      subscriptionChangeType: "expiry_enforcement",
      subscriptionProvider: cleanText(data.subscriptionProvider),
      previousSubscriptionExpiresAt: readDate(
          data.subscriptionExpiresAt,
      )?.toISOString(),
      createdAt: FieldValue.serverTimestamp(),
    });

    expiredUsers.push(cleanEmail(data.email || doc.id));
  }

  return {
    checkedCount: snapshot.docs ? snapshot.docs.length : 0,
    expiredCount: expiredUsers.length,
    expiredUsers,
  };
}

function shouldExpireUser(data, now = new Date()) {
  if (!data || cleanText(data.role) === "admin") return false;
  if (!EXPIRABLE_STATUSES.has(cleanText(data.subscriptionStatus))) {
    return false;
  }
  if (!EXPIRABLE_PROVIDERS.has(cleanText(data.subscriptionProvider))) {
    return false;
  }

  const expiresAt = readDate(data.subscriptionExpiresAt);
  if (!expiresAt) return false;

  return expiresAt.getTime() <= now.getTime();
}

function readDate(value) {
  if (!value) return null;
  if (value instanceof Date) {
    return Number.isFinite(value.getTime()) ? value : null;
  }

  if (typeof value.toDate === "function") {
    const date = value.toDate();
    return date instanceof Date && Number.isFinite(date.getTime()) ?
      date :
      null;
  }

  const parsed = new Date(Date.parse(value.toString()));
  return Number.isFinite(parsed.getTime()) ? parsed : null;
}

function cleanText(value) {
  return value == null ? "" : value.toString().trim().toLowerCase();
}

function cleanEmail(value) {
  return cleanText(value);
}

module.exports = {
  createExpireSubscriptionsHandler,
  expireDueSubscriptions,
  shouldExpireUser,
};

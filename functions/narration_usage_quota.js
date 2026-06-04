const {createHash} = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const DEFAULT_DAILY_LIMITS = Object.freeze({
  premium: Object.freeze({
    characters: 120000,
    requests: 100,
  }),
  admin: Object.freeze({
    characters: 600000,
    requests: 500,
  }),
});

function createNarrationUsageQuota({
  firestore,
  dailyLimits = DEFAULT_DAILY_LIMITS,
  now = () => new Date(),
  serverTimestamp = () => FieldValue.serverTimestamp(),
}) {
  requireFunction(firestore && firestore.runTransaction, "runTransaction");
  requireFunction(now, "now");
  requireFunction(serverTimestamp, "serverTimestamp");
  const limits = validateDailyLimits(dailyLimits);

  return {
    async consume({uid, access, characterCount}) {
      const normalizedUid = requireUid(uid);
      const plan = planForAccess(access);
      const limit = limits[plan];
      const safeCharacterCount = requireCharacterCount(characterCount);
      const dateKey = utcDateKey(now());
      const usageId = usageDocumentId(normalizedUid, dateKey);
      const usageReference = firestore
          .collection("cloud_narration_usage")
          .doc(usageId);

      return firestore.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(usageReference);
        const currentUsage = snapshot.exists ?
          validateStoredUsage(snapshot.data()) :
          {characters: 0, requests: 0};
        const nextUsage = {
          characters: currentUsage.characters + safeCharacterCount,
          requests: currentUsage.requests + 1,
        };

        if (nextUsage.characters > limit.characters ||
            nextUsage.requests > limit.requests) {
          throw new HttpsError(
              "resource-exhausted",
              "Your daily cloud narration allowance has been reached.",
          );
        }

        transaction.set(
            usageReference,
            {
              dateKey,
              plan,
              characterCount: nextUsage.characters,
              requestCount: nextUsage.requests,
              updatedAt: serverTimestamp(),
            },
            {merge: true},
        );

        return {
          dateKey,
          plan,
          usedCharacters: nextUsage.characters,
          usedRequests: nextUsage.requests,
          remainingCharacters: limit.characters - nextUsage.characters,
          remainingRequests: limit.requests - nextUsage.requests,
        };
      });
    },
  };
}

function planForAccess(access) {
  if (!isPlainObject(access)) {
    throw new HttpsError(
        "permission-denied",
        "Premium narration is required for cloud and customized voices.",
    );
  }
  if (access.role === "admin") return "admin";
  if (access.subscriptionStatus === "active") return "premium";

  throw new HttpsError(
      "permission-denied",
      "Premium narration is required for cloud and customized voices.",
  );
}

function usageDocumentId(uid, dateKey) {
  const uidHash = createHash("sha256").update(uid).digest("hex");
  return `${uidHash}_${dateKey}`;
}

function utcDateKey(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) {
    throw new TypeError("now must return a valid Date.");
  }

  return value.toISOString().slice(0, 10);
}

function validateStoredUsage(value) {
  if (!isPlainObject(value)) throw invalidStoredUsageError();

  return {
    characters: requireNonNegativeInteger(
        value.characterCount,
        invalidStoredUsageError,
    ),
    requests: requireNonNegativeInteger(
        value.requestCount,
        invalidStoredUsageError,
    ),
  };
}

function validateDailyLimits(value) {
  if (!isPlainObject(value)) throw new TypeError("dailyLimits is invalid.");

  return Object.freeze({
    premium: validatePlanLimit(value.premium, "premium"),
    admin: validatePlanLimit(value.admin, "admin"),
  });
}

function validatePlanLimit(value, plan) {
  if (!isPlainObject(value)) {
    throw new TypeError(`${plan} narration limits are invalid.`);
  }

  return Object.freeze({
    characters: requirePositiveInteger(value.characters, plan),
    requests: requirePositiveInteger(value.requests, plan),
  });
}

function requirePositiveInteger(value, fieldName) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new TypeError(`${fieldName} narration limit is invalid.`);
  }
  return value;
}

function requireCharacterCount(value) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new HttpsError(
        "invalid-argument",
        "A valid narration character count is required.",
    );
  }
  return value;
}

function requireUid(value) {
  if (typeof value !== "string" || value.trim() === "") {
    throw new HttpsError(
        "unauthenticated",
        "Sign in before using cloud narration.",
    );
  }
  return value.trim();
}

function requireNonNegativeInteger(value, errorFactory) {
  if (!Number.isSafeInteger(value) || value < 0) throw errorFactory();
  return value;
}

function invalidStoredUsageError() {
  return new HttpsError(
      "internal",
      "Cloud narration usage could not be verified.",
  );
}

function requireFunction(value, name) {
  if (typeof value !== "function") {
    throw new TypeError(`${name} must be a function.`);
  }
}

function isPlainObject(value) {
  return value !== null &&
    typeof value === "object" &&
    !Array.isArray(value);
}

module.exports = {
  DEFAULT_DAILY_LIMITS,
  createNarrationUsageQuota,
  planForAccess,
  usageDocumentId,
  utcDateKey,
};

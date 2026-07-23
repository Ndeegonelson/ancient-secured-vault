const crypto = require("crypto");
const {GoogleAuth} = require("google-auth-library");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue} = require("firebase-admin/firestore");

const ANDROID_PACKAGE_NAME = "tech.ancientsociety.vault";
const PREMIUM_YEARLY_PRODUCT_ID =
  "tech.ancientsociety.vault.premium.yearly";
const GOOGLE_PLAY_PROVIDER = "google_play";
const ANDROID_PUBLISHER_BASE_URL =
  "https://androidpublisher.googleapis.com/androidpublisher/v3";
const ANDROID_PUBLISHER_SCOPE =
  "https://www.googleapis.com/auth/androidpublisher";
const googlePlayAuth = createAndroidPublisherAuth();
const ENTITLED_SUBSCRIPTION_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED",
]);
const GOOGLE_PLAY_NOTIFICATION_TYPES = Object.freeze({
  1: "recovered",
  2: "renewed",
  3: "cancelled",
  4: "purchased",
  5: "on_hold",
  6: "in_grace_period",
  7: "restarted",
  9: "deferred",
  10: "paused",
  11: "pause_schedule_changed",
  12: "revoked",
  13: "expired",
  19: "price_step_up_consent_updated",
});

function createVerifyGooglePlayPurchaseHandler({
  firestore,
  verifyIdToken = (token) => getAuth().verifyIdToken(token),
  fetchSubscription = defaultFetchSubscription,
  acknowledgeSubscription = defaultAcknowledgeSubscription,
} = {}) {
  if (!firestore) throw new TypeError("Firestore is required.");

  return async (request, response) => {
    try {
      if (request.method !== "POST") {
        throw playError(405, "Google Play purchase verification requires POST.");
      }

      const auth = await verifyIdToken(bearerToken(request));
      const userEmail = cleanEmail(auth && auth.email);
      const userUid = cleanText(auth && auth.uid);
      if (!userEmail || !userUid) {
        throw playError(401, "A verified account is required.");
      }

      const input = request.body && request.body.data ?
        request.body.data : request.body;
      const purchaseToken = cleanText(input && input.purchaseToken);
      const productId = cleanText(input && input.productId);
      if (!purchaseToken) {
        throw playError(400, "Google Play purchase token is missing.");
      }
      if (productId !== PREMIUM_YEARLY_PRODUCT_ID) {
        throw playError(400, "This Google Play product does not unlock premium access.");
      }

      const subscription = await fetchSubscription({purchaseToken});
      const expectedAccountId = googlePlayAccountId(userUid);
      const verified = validateGooglePlaySubscription(subscription, {
        productId,
        expectedAccountId,
      });

      if (verified.needsAcknowledgement) {
        await acknowledgeSubscription({purchaseToken, productId});
      }

      const result = await activateGooglePlaySubscription({
        firestore,
        userEmail,
        userUid,
        purchaseToken,
        productId,
        subscription,
        verified,
        source: cleanText(input && input.source) || "purchase",
      });
      response.json(result);
    } catch (error) {
      console.error("Google Play purchase handler failed", {
        status: error && error.status ? error.status : 500,
        message: error && error.message ? error.message : "Unknown error",
      });
      response.status(error && error.status ? error.status : 500).json({
        error: error && error.message ?
          error.message : "Google Play purchase verification failed.",
      });
    }
  };
}

function createGooglePlayRtdnHandler({
  firestore,
  fetchSubscription = defaultFetchSubscription,
} = {}) {
  if (!firestore) throw new TypeError("Firestore is required.");

  return async (event) => {
    const notification = decodeGooglePlayRtdn(event);
    if (notification.packageName !== ANDROID_PACKAGE_NAME) {
      return {ignored: true, reason: "other_package"};
    }

    const subscriptionNotification = notification.subscriptionNotification;
    if (!subscriptionNotification) {
      return {ignored: true, reason: "not_a_subscription"};
    }

    const productId = cleanText(subscriptionNotification.subscriptionId);
    if (productId !== PREMIUM_YEARLY_PRODUCT_ID) {
      return {ignored: true, reason: "other_product"};
    }

    const purchaseToken = cleanText(subscriptionNotification.purchaseToken);
    if (!purchaseToken) {
      throw playError(400, "Google Play notification has no purchase token.");
    }

    const subscription = await fetchSubscription({purchaseToken});
    const snapshot = googlePlayLifecycleSnapshot(subscription, {productId});
    return syncGooglePlaySubscriptionNotification({
      firestore,
      eventId: notification.eventId,
      eventTime: notification.eventTime,
      notificationType: subscriptionNotification.notificationType,
      purchaseToken,
      productId,
      subscription,
      snapshot,
    });
  };
}

async function defaultFetchSubscription({purchaseToken, fetchImpl = fetch}) {
  const accessToken = await googleAccessToken();
  const url = `${ANDROID_PUBLISHER_BASE_URL}/applications/${
    encodeURIComponent(ANDROID_PACKAGE_NAME)
  }/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetchImpl(url, {
    method: "GET",
    headers: {
      "Accept": "application/json",
      "Authorization": `Bearer ${accessToken}`,
    },
  });
  const body = await readJson(response);
  if (!response.ok) {
    console.error("Google Play subscription verification failed", {
      status: response.status,
      error: body && body.error && body.error.message,
    });
    throw playError(502, "Google Play could not verify this subscription.");
  }
  return body;
}

async function defaultAcknowledgeSubscription({
  purchaseToken,
  productId,
  fetchImpl = fetch,
}) {
  const accessToken = await googleAccessToken();
  const url = `${ANDROID_PUBLISHER_BASE_URL}/applications/${
    encodeURIComponent(ANDROID_PACKAGE_NAME)
  }/purchases/subscriptions/${
    encodeURIComponent(productId)
  }/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
  const response = await fetchImpl(url, {
    method: "POST",
    headers: {
      "Accept": "application/json",
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  });
  if (!response.ok) {
    const body = await readJson(response);
    console.error("Google Play subscription acknowledgement failed", {
      status: response.status,
      error: body && body.error && body.error.message,
    });
    throw playError(502, "Google Play purchase acknowledgement failed.");
  }
}

function createAndroidPublisherAuth(GoogleAuthConstructor = GoogleAuth) {
  return new GoogleAuthConstructor({scopes: [ANDROID_PUBLISHER_SCOPE]});
}

async function googleAccessToken(auth = googlePlayAuth) {
  if (!auth || typeof auth.getAccessToken !== "function") {
    throw playError(500, "Google Play verification credentials are unavailable.");
  }
  const token = await auth.getAccessToken();
  const accessToken = cleanText(
      typeof token === "string" ? token : token && token.token,
  );
  if (!accessToken) {
    throw playError(500, "Google Play verification credentials are unavailable.");
  }
  return accessToken;
}

function validateGooglePlaySubscription(subscription, {
  productId = PREMIUM_YEARLY_PRODUCT_ID,
  expectedAccountId,
  now = Date.now(),
} = {}) {
  if (!subscription || typeof subscription !== "object") {
    throw playError(400, "Google Play returned an invalid subscription.");
  }
  const state = cleanText(subscription.subscriptionState).toUpperCase();
  if (!ENTITLED_SUBSCRIPTION_STATES.has(state)) {
    throw playError(409, googlePlayStateMessage(state));
  }

  const lineItems = Array.isArray(subscription.lineItems) ?
    subscription.lineItems : [];
  const matchingItems = lineItems.filter(
      (item) => cleanText(item && item.productId) === productId,
  );
  if (matchingItems.length === 0) {
    throw playError(400, "Google Play verified a different subscription product.");
  }
  const expiryTimes = matchingItems
      .map((item) => readDate(item && item.expiryTime))
      .filter(Boolean);
  const expiresAt = expiryTimes.sort(
      (left, right) => right.getTime() - left.getTime(),
  )[0];
  if (!expiresAt || expiresAt.getTime() <= now) {
    throw playError(409, "This Google Play subscription has expired.");
  }

  const accountId = cleanText(
      subscription.externalAccountIdentifiers &&
      subscription.externalAccountIdentifiers.obfuscatedExternalAccountId,
  );
  if (!accountId || !safeCompare(accountId, cleanText(expectedAccountId))) {
    throw playError(409, "This Google Play purchase belongs to another account.");
  }

  return {
    state,
    expiresAt,
    latestOrderId: cleanText(subscription.latestOrderId),
    linkedPurchaseToken: cleanText(subscription.linkedPurchaseToken),
    environment: subscription.testPurchase ? "test" : "production",
    needsAcknowledgement:
      cleanText(subscription.acknowledgementState).toUpperCase() !==
      "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
  };
}

async function activateGooglePlaySubscription({
  firestore,
  userEmail,
  userUid,
  purchaseToken,
  productId,
  subscription,
  verified,
  source,
}) {
  const tokenHash = purchaseTokenHash(purchaseToken);
  const purchaseRef = firestore
      .collection("google_play_subscription_purchases")
      .doc(tokenHash);
  const userRef = firestore.collection("users").doc(userEmail);

  await firestore.runTransaction(async (transaction) => {
    const existing = await transaction.get(purchaseRef);
    const existingEmail = existing.exists ?
      cleanEmail(existing.data().userEmail) : "";
    if (existingEmail && existingEmail !== userEmail) {
      throw playError(409, "This Google Play purchase belongs to another account.");
    }

    transaction.set(purchaseRef, {
      userEmail,
      userUid,
      productId,
      purchaseToken,
      purchaseTokenHash: tokenHash,
      subscriptionState: verified.state,
      environment: verified.environment,
      latestOrderId: verified.latestOrderId,
      linkedPurchaseToken: verified.linkedPurchaseToken,
      source,
      expiresAt: verified.expiresAt,
      regionCode: cleanText(subscription.regionCode),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(userRef, {
      email: userEmail,
      userUid,
      role: "reader",
      accessLevel: "premium",
      subscriptionStatus: "active",
      subscriptionProvider: GOOGLE_PLAY_PROVIDER,
      subscriptionReference: verified.latestOrderId || tokenHash,
      subscriptionExpiresAt: verified.expiresAt,
      googlePlayProductId: productId,
      googlePlayPurchaseTokenHash: tokenHash,
      googlePlayLatestOrderId: verified.latestOrderId,
      googlePlaySubscriptionState: verified.state,
      googlePlayEnvironment: verified.environment,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  return {
    accessLevel: "premium",
    subscriptionStatus: "active",
    subscriptionProvider: GOOGLE_PLAY_PROVIDER,
    productId,
    environment: verified.environment,
    expiresAt: verified.expiresAt.toISOString(),
  };
}

function decodeGooglePlayRtdn(event) {
  const message = event && event.data && event.data.message ?
    event.data.message : event && event.message ? event.message : {};
  const encodedData = message && message.data;
  let decoded;
  try {
    const json = Buffer.isBuffer(encodedData) ?
      encodedData.toString("utf8") :
      Buffer.from(cleanText(encodedData), "base64").toString("utf8");
    decoded = JSON.parse(json);
  } catch (_) {
    throw playError(400, "Google Play notification data is invalid.");
  }

  if (!decoded || typeof decoded !== "object") {
    throw playError(400, "Google Play notification data is invalid.");
  }

  const eventId = cleanText(message.messageId) || cleanText(event && event.id) ||
    crypto.createHash("sha256").update(JSON.stringify(decoded)).digest("hex");
  const eventTimeMillis = Number(decoded.eventTimeMillis);
  const eventTime = Number.isFinite(eventTimeMillis) && eventTimeMillis > 0 ?
    new Date(eventTimeMillis) : null;

  return {
    ...decoded,
    eventId,
    eventTime,
  };
}

function googlePlayLifecycleSnapshot(subscription, {
  productId = PREMIUM_YEARLY_PRODUCT_ID,
  now = Date.now(),
} = {}) {
  if (!subscription || typeof subscription !== "object") {
    throw playError(400, "Google Play returned an invalid subscription.");
  }

  const state = cleanText(subscription.subscriptionState).toUpperCase();
  const lineItems = Array.isArray(subscription.lineItems) ?
    subscription.lineItems : [];
  const matchingItems = lineItems.filter(
      (item) => cleanText(item && item.productId) === productId,
  );
  if (matchingItems.length === 0) {
    throw playError(400, "Google Play verified a different subscription product.");
  }

  const expiresAt = matchingItems
      .map((item) => readDate(item && item.expiryTime))
      .filter(Boolean)
      .sort((left, right) => right.getTime() - left.getTime())[0] || null;
  const unexpired = Boolean(expiresAt && expiresAt.getTime() > now);
  const entitled = unexpired && ENTITLED_SUBSCRIPTION_STATES.has(state);
  const autoRenewing = matchingItems.some((item) => Boolean(
      item && item.autoRenewingPlan && item.autoRenewingPlan.autoRenewEnabled,
  ));

  return {
    state,
    entitled,
    expiresAt,
    autoRenewing,
    latestOrderId: cleanText(subscription.latestOrderId),
    linkedPurchaseToken: cleanText(subscription.linkedPurchaseToken),
    environment: subscription.testPurchase ? "test" : "production",
    subscriptionStatus: entitled ? "active" : lifecycleStatus(state, unexpired),
  };
}

async function syncGooglePlaySubscriptionNotification({
  firestore,
  eventId,
  eventTime,
  notificationType,
  purchaseToken,
  productId,
  subscription,
  snapshot,
}) {
  const tokenHash = purchaseTokenHash(purchaseToken);
  const eventHash = crypto.createHash("sha256")
      .update(cleanText(eventId))
      .digest("hex");
  const purchaseRef = firestore
      .collection("google_play_subscription_purchases")
      .doc(tokenHash);
  const eventRef = firestore
      .collection("google_play_rtdn_events")
      .doc(eventHash);
  let result;

  await firestore.runTransaction(async (transaction) => {
    const previousEvent = await transaction.get(eventRef);
    if (previousEvent.exists) {
      result = {duplicate: true, eventId};
      return;
    }

    const purchaseDocument = await transaction.get(purchaseRef);
    if (!purchaseDocument.exists) {
      result = {
        eventId,
        ignored: true,
        reason: "unknown_purchase",
        notificationType: Number(notificationType) || 0,
      };
      transaction.set(eventRef, {
        ...result,
        purchaseTokenHash: tokenHash,
        productId,
        subscriptionState: snapshot.state,
        eventTime,
        processedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    const purchase = purchaseDocument.data();
    const userEmail = cleanEmail(purchase.userEmail);
    if (!userEmail) {
      throw playError(409, "Google Play purchase has no Ancient Vault owner.");
    }

    const userRef = firestore.collection("users").doc(userEmail);
    const userDocument = await transaction.get(userRef);
    const user = userDocument.exists ? userDocument.data() : {};
    const ownsCurrentEntitlement =
      cleanText(user.subscriptionProvider) === GOOGLE_PLAY_PROVIDER &&
      cleanText(user.googlePlayPurchaseTokenHash) === tokenHash;
    const notificationName = GOOGLE_PLAY_NOTIFICATION_TYPES[
      Number(notificationType)
    ] || "unknown";

    transaction.set(purchaseRef, {
      subscriptionState: snapshot.state,
      lifecycleStatus: snapshot.subscriptionStatus,
      autoRenewing: snapshot.autoRenewing,
      environment: snapshot.environment,
      latestOrderId: snapshot.latestOrderId,
      linkedPurchaseToken: snapshot.linkedPurchaseToken,
      expiresAt: snapshot.expiresAt,
      lastNotificationType: Number(notificationType) || 0,
      lastNotificationName: notificationName,
      lastNotificationEventId: eventId,
      lastNotificationEventTime: eventTime,
      regionCode: cleanText(subscription.regionCode),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    if (ownsCurrentEntitlement) {
      transaction.set(userRef, {
        accessLevel: snapshot.entitled ? "premium" : "free",
        subscriptionStatus: snapshot.subscriptionStatus,
        subscriptionProvider: GOOGLE_PLAY_PROVIDER,
        subscriptionReference: snapshot.latestOrderId || tokenHash,
        ...(snapshot.expiresAt ? {
          subscriptionExpiresAt: snapshot.expiresAt,
        } : {}),
        googlePlayLatestOrderId: snapshot.latestOrderId,
        googlePlaySubscriptionState: snapshot.state,
        googlePlayAutoRenewing: snapshot.autoRenewing,
        googlePlayEnvironment: snapshot.environment,
        googlePlayLastNotificationType: Number(notificationType) || 0,
        googlePlayLastNotificationName: notificationName,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    result = {
      eventId,
      userEmail,
      active: snapshot.entitled,
      subscriptionStatus: snapshot.subscriptionStatus,
      notificationType: Number(notificationType) || 0,
      notificationName,
      ignored: !ownsCurrentEntitlement,
      ...(ownsCurrentEntitlement ? {} : {reason: "superseded_entitlement"}),
    };
    transaction.set(eventRef, {
      ...result,
      purchaseTokenHash: tokenHash,
      productId,
      subscriptionState: snapshot.state,
      eventTime,
      processedAt: FieldValue.serverTimestamp(),
    });
  });

  return result;
}

function lifecycleStatus(state, unexpired) {
  if (!unexpired || state === "SUBSCRIPTION_STATE_EXPIRED") return "expired";
  return switchState(state, {
    SUBSCRIPTION_STATE_ON_HOLD: "on_hold",
    SUBSCRIPTION_STATE_PAUSED: "paused",
    SUBSCRIPTION_STATE_PENDING: "pending",
    SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED: "cancelled",
    default: "inactive",
  });
}

function googlePlayAccountId(uid) {
  return crypto.createHash("sha256").update(cleanText(uid)).digest("hex");
}

function purchaseTokenHash(purchaseToken) {
  return crypto
      .createHash("sha256")
      .update(cleanText(purchaseToken))
      .digest("hex");
}

function googlePlayStateMessage(state) {
  return switchState(state, {
    SUBSCRIPTION_STATE_PENDING: "Google Play is still processing this payment.",
    SUBSCRIPTION_STATE_PAUSED: "This Google Play subscription is paused.",
    SUBSCRIPTION_STATE_ON_HOLD: "This Google Play subscription is on hold.",
    SUBSCRIPTION_STATE_EXPIRED: "This Google Play subscription has expired.",
    default: "This Google Play subscription is not active.",
  });
}

function switchState(value, values) {
  return Object.prototype.hasOwnProperty.call(values, value) ?
    values[value] : values.default;
}

function bearerToken(request) {
  const authorization = request.get("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) throw playError(401, "Sign in before verifying a purchase.");
  return match[1];
}

function readDate(value) {
  const date = new Date(cleanText(value));
  return Number.isFinite(date.getTime()) ? date : null;
}

async function readJson(response) {
  try {
    return await response.json();
  } catch (_) {
    return {};
  }
}

function safeCompare(left, right) {
  const leftBuffer = Buffer.from(cleanText(left));
  const rightBuffer = Buffer.from(cleanText(right));
  return leftBuffer.length === rightBuffer.length &&
    crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function cleanText(value) {
  return value === undefined || value === null ? "" : String(value).trim();
}

function cleanEmail(value) {
  return cleanText(value).toLowerCase();
}

function playError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

module.exports = {
  ANDROID_PACKAGE_NAME,
  ANDROID_PUBLISHER_SCOPE,
  PREMIUM_YEARLY_PRODUCT_ID,
  activateGooglePlaySubscription,
  createAndroidPublisherAuth,
  createGooglePlayRtdnHandler,
  createVerifyGooglePlayPurchaseHandler,
  decodeGooglePlayRtdn,
  googleAccessToken,
  googlePlayAccountId,
  googlePlayLifecycleSnapshot,
  purchaseTokenHash,
  syncGooglePlaySubscriptionNotification,
  validateGooglePlaySubscription,
};

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  ANDROID_PUBLISHER_SCOPE,
  PREMIUM_YEARLY_PRODUCT_ID,
  activateGooglePlaySubscription,
  createAndroidPublisherAuth,
  createGooglePlayRtdnHandler,
  createGooglePlayReconciliationHandler,
  createVerifyGooglePlayPurchaseHandler,
  decodeGooglePlayRtdn,
  googleAccessToken,
  googlePlayAccountId,
  googlePlayLifecycleSnapshot,
  purchaseTokenHash,
  validateGooglePlaySubscription,
} = require("../google_play_subscription");

test("creates credentials with the Android Publisher OAuth scope", async () => {
  let options;
  class FakeGoogleAuth {
    constructor(receivedOptions) {
      options = receivedOptions;
    }
  }

  createAndroidPublisherAuth(FakeGoogleAuth);
  assert.deepEqual(options, {scopes: [ANDROID_PUBLISHER_SCOPE]});
  assert.equal(
      await googleAccessToken({getAccessToken: async () => "scoped-token"}),
      "scoped-token",
  );
});

function fakeRequest(body) {
  return {
    method: "POST",
    body,
    get(name) {
      return name.toLowerCase() === "authorization" ? "Bearer firebase-token" : "";
    },
  };
}

function fakeResponse() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

function activeSubscription({uid = "firebase-user-1", overrides = {}} = {}) {
  return {
    kind: "androidpublisher#subscriptionPurchaseV2",
    regionCode: "GH",
    startTime: "2026-07-23T00:00:00Z",
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
    latestOrderId: "GPA.1234-5678-9012-34567",
    lineItems: [{
      productId: PREMIUM_YEARLY_PRODUCT_ID,
      expiryTime: "2027-07-23T00:00:00Z",
      autoRenewingPlan: {autoRenewEnabled: true},
    }],
    externalAccountIdentifiers: {
      obfuscatedExternalAccountId: googlePlayAccountId(uid),
    },
    testPurchase: {},
    ...overrides,
  };
}

function createFirestore() {
  const documents = new Map();
  return {
    documents,
    collection(name) {
      return {
        doc(id) {
          return {collection: name, id, key: `${name}/${id}`};
        },
      };
    },
    async runTransaction(callback) {
      await callback({
        async get(ref) {
          const data = documents.get(ref.key);
          return {exists: Boolean(data), data: () => data};
        },
        set(ref, data, options) {
          const previous = documents.get(ref.key) || {};
          documents.set(
              ref.key,
              options && options.merge ? {...previous, ...data} : data,
          );
        },
      });
    },
  };
}

function rtdnEvent({
  messageId = "rtdn-message-1",
  notificationType = 2,
  purchaseToken = "rtdn-purchase-token",
  productId = PREMIUM_YEARLY_PRODUCT_ID,
  packageName = "tech.ancientsociety.vault",
} = {}) {
  const payload = {
    version: "1.0",
    packageName,
    eventTimeMillis: "1784840400000",
    subscriptionNotification: {
      version: "1.0",
      notificationType,
      purchaseToken,
      subscriptionId: productId,
    },
  };
  return {
    id: `cloud-${messageId}`,
    data: {
      message: {
        messageId,
        data: Buffer.from(JSON.stringify(payload)).toString("base64"),
      },
    },
  };
}

test("validates an entitled annual Google Play subscription", () => {
  const verified = validateGooglePlaySubscription(activeSubscription(), {
    expectedAccountId: googlePlayAccountId("firebase-user-1"),
    now: Date.parse("2026-07-23T12:00:00Z"),
  });

  assert.equal(verified.state, "SUBSCRIPTION_STATE_ACTIVE");
  assert.equal(verified.environment, "test");
  assert.equal(verified.needsAcknowledgement, true);
  assert.equal(verified.expiresAt.toISOString(), "2027-07-23T00:00:00.000Z");
});

test("accepts cancellation only while paid access remains unexpired", () => {
  const verified = validateGooglePlaySubscription(activeSubscription({
    overrides: {subscriptionState: "SUBSCRIPTION_STATE_CANCELED"},
  }), {
    expectedAccountId: googlePlayAccountId("firebase-user-1"),
    now: Date.parse("2026-07-23T12:00:00Z"),
  });
  assert.equal(verified.state, "SUBSCRIPTION_STATE_CANCELED");

  assert.throws(
      () => validateGooglePlaySubscription(activeSubscription({
        overrides: {
          subscriptionState: "SUBSCRIPTION_STATE_CANCELED",
          lineItems: [{
            productId: PREMIUM_YEARLY_PRODUCT_ID,
            expiryTime: "2026-07-22T00:00:00Z",
          }],
        },
      }), {
        expectedAccountId: googlePlayAccountId("firebase-user-1"),
        now: Date.parse("2026-07-23T12:00:00Z"),
      }),
      /expired/i,
  );
});

test("rejects pending, unrelated, and cross-account purchases", () => {
  assert.throws(
      () => validateGooglePlaySubscription(activeSubscription({
        overrides: {subscriptionState: "SUBSCRIPTION_STATE_PENDING"},
      }), {expectedAccountId: googlePlayAccountId("firebase-user-1")}),
      /processing/i,
  );
  assert.throws(
      () => validateGooglePlaySubscription(activeSubscription({
        overrides: {lineItems: [{
          productId: "other.product",
          expiryTime: "2027-07-23T00:00:00Z",
        }]},
      }), {expectedAccountId: googlePlayAccountId("firebase-user-1")}),
      /different subscription product/i,
  );
  assert.throws(
      () => validateGooglePlaySubscription(activeSubscription(), {
        expectedAccountId: googlePlayAccountId("firebase-user-2"),
      }),
      /belongs to another account/i,
  );
});

test("activates premium and prevents purchase token reuse", async () => {
  const firestore = createFirestore();
  const purchaseToken = "test-purchase-token";
  const subscription = activeSubscription();
  const verified = validateGooglePlaySubscription(subscription, {
    expectedAccountId: googlePlayAccountId("firebase-user-1"),
  });

  const result = await activateGooglePlaySubscription({
    firestore,
    userEmail: "reader@example.com",
    userUid: "firebase-user-1",
    purchaseToken,
    productId: PREMIUM_YEARLY_PRODUCT_ID,
    subscription,
    verified,
    source: "purchase",
  });
  assert.equal(result.subscriptionProvider, "google_play");
  const user = firestore.documents.get("users/reader@example.com");
  assert.equal(user.accessLevel, "premium");
  assert.equal(user.googlePlayEnvironment, "test");
  assert.equal(
      user.googlePlayPurchaseTokenHash,
      purchaseTokenHash(purchaseToken),
  );

  await assert.rejects(
      activateGooglePlaySubscription({
        firestore,
        userEmail: "other@example.com",
        userUid: "firebase-user-2",
        purchaseToken,
        productId: PREMIUM_YEARLY_PRODUCT_ID,
        subscription,
        verified,
        source: "restore",
      }),
      /belongs to another account/i,
  );
});

test("verifies, grants, and acknowledges through the authenticated handler", async () => {
  const firestore = createFirestore();
  const calls = [];
  const handler = createVerifyGooglePlayPurchaseHandler({
    firestore,
    verifyIdToken: async (token) => {
      assert.equal(token, "firebase-token");
      return {uid: "firebase-user-1", email: "reader@example.com"};
    },
    fetchSubscription: async ({purchaseToken}) => {
      calls.push(`verify:${purchaseToken}`);
      return activeSubscription();
    },
    acknowledgeSubscription: async ({purchaseToken, productId}) => {
      assert.equal(productId, PREMIUM_YEARLY_PRODUCT_ID);
      calls.push(`acknowledge:${purchaseToken}`);
    },
  });
  const response = fakeResponse();

  await handler(fakeRequest({
    productId: PREMIUM_YEARLY_PRODUCT_ID,
    purchaseToken: "verified-token",
    source: "purchase",
  }), response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.subscriptionProvider, "google_play");
  assert.equal(response.body.environment, "test");
  assert.deepEqual(calls, [
    "verify:verified-token",
    "acknowledge:verified-token",
  ]);
  assert.equal(
      firestore.documents.get("users/reader@example.com").subscriptionStatus,
      "active",
  );
});

test("does not grant premium when Google Play acknowledgement fails", async () => {
  const firestore = createFirestore();
  const handler = createVerifyGooglePlayPurchaseHandler({
    firestore,
    verifyIdToken: async () => ({
      uid: "firebase-user-1",
      email: "reader@example.com",
    }),
    fetchSubscription: async () => activeSubscription(),
    acknowledgeSubscription: async () => {
      throw Object.assign(new Error("Acknowledgement rejected."), {status: 502});
    },
  });
  const response = fakeResponse();

  await handler(fakeRequest({
    productId: PREMIUM_YEARLY_PRODUCT_ID,
    purchaseToken: "unacknowledged-token",
    source: "purchase",
  }), response);

  assert.equal(response.statusCode, 502);
  assert.equal(firestore.documents.has("users/reader@example.com"), false);
});

test("decodes a Google Play real-time developer notification", () => {
  const decoded = decodeGooglePlayRtdn(rtdnEvent());
  assert.equal(decoded.eventId, "rtdn-message-1");
  assert.equal(decoded.packageName, "tech.ancientsociety.vault");
  assert.equal(decoded.subscriptionNotification.notificationType, 2);
  assert.ok(decoded.eventTime instanceof Date);
});

test("maps renewal and cancellation to an active paid entitlement", () => {
  const renewed = googlePlayLifecycleSnapshot(activeSubscription({
    overrides: {
      acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
      lineItems: [{
        productId: PREMIUM_YEARLY_PRODUCT_ID,
        expiryTime: "2028-07-23T00:00:00Z",
        autoRenewingPlan: {autoRenewEnabled: true},
      }],
    },
  }), {now: Date.parse("2026-07-23T12:00:00Z")});
  assert.equal(renewed.entitled, true);
  assert.equal(renewed.autoRenewing, true);

  const cancelled = googlePlayLifecycleSnapshot(activeSubscription({
    overrides: {
      subscriptionState: "SUBSCRIPTION_STATE_CANCELED",
      lineItems: [{
        productId: PREMIUM_YEARLY_PRODUCT_ID,
        expiryTime: "2026-08-23T00:00:00Z",
        autoRenewingPlan: {autoRenewEnabled: false},
      }],
    },
  }), {now: Date.parse("2026-07-23T12:00:00Z")});
  assert.equal(cancelled.entitled, true);
  assert.equal(cancelled.subscriptionStatus, "active");
  assert.equal(cancelled.autoRenewing, false);
});

test("RTDN renewal extends access and duplicate delivery is idempotent", async () => {
  const firestore = createFirestore();
  const purchaseToken = "rtdn-purchase-token";
  const initial = activeSubscription();
  await activateGooglePlaySubscription({
    firestore,
    userEmail: "reader@example.com",
    userUid: "firebase-user-1",
    purchaseToken,
    productId: PREMIUM_YEARLY_PRODUCT_ID,
    subscription: initial,
    verified: validateGooglePlaySubscription(initial, {
      expectedAccountId: googlePlayAccountId("firebase-user-1"),
    }),
    source: "purchase",
  });

  const renewed = activeSubscription({
    overrides: {
      acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
      lineItems: [{
        productId: PREMIUM_YEARLY_PRODUCT_ID,
        expiryTime: "2028-07-23T00:00:00Z",
        autoRenewingPlan: {autoRenewEnabled: true},
      }],
    },
  });
  const handler = createGooglePlayRtdnHandler({
    firestore,
    fetchSubscription: async () => renewed,
  });

  const first = await handler(rtdnEvent({purchaseToken}));
  const second = await handler(rtdnEvent({purchaseToken}));
  const user = firestore.documents.get("users/reader@example.com");
  assert.equal(first.notificationName, "renewed");
  assert.equal(first.active, true);
  assert.equal(second.duplicate, true);
  assert.equal(
      user.subscriptionExpiresAt.toISOString(),
      "2028-07-23T00:00:00.000Z",
  );
});

test("RTDN removes access after expiry, revocation, hold, or pause", async () => {
  const cases = [
    ["SUBSCRIPTION_STATE_EXPIRED", 13, "expired"],
    ["SUBSCRIPTION_STATE_EXPIRED", 12, "expired"],
    ["SUBSCRIPTION_STATE_ON_HOLD", 5, "on_hold"],
    ["SUBSCRIPTION_STATE_PAUSED", 10, "paused"],
  ];

  for (const [state, notificationType, expectedStatus] of cases) {
    const firestore = createFirestore();
    const purchaseToken = `inactive-token-${notificationType}`;
    const initial = activeSubscription();
    await activateGooglePlaySubscription({
      firestore,
      userEmail: `reader-${notificationType}@example.com`,
      userUid: "firebase-user-1",
      purchaseToken,
      productId: PREMIUM_YEARLY_PRODUCT_ID,
      subscription: initial,
      verified: validateGooglePlaySubscription(initial, {
        expectedAccountId: googlePlayAccountId("firebase-user-1"),
      }),
      source: "purchase",
    });
    const inactive = activeSubscription({
      overrides: {
        subscriptionState: state,
        acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
        lineItems: [{
          productId: PREMIUM_YEARLY_PRODUCT_ID,
          expiryTime: state === "SUBSCRIPTION_STATE_EXPIRED" ?
            "2026-07-22T00:00:00Z" : "2027-07-23T00:00:00Z",
        }],
      },
    });
    const handler = createGooglePlayRtdnHandler({
      firestore,
      fetchSubscription: async () => inactive,
    });

    await handler(rtdnEvent({
      messageId: `inactive-${notificationType}`,
      notificationType,
      purchaseToken,
    }));
    const user = firestore.documents.get(
        `users/reader-${notificationType}@example.com`,
    );
    assert.equal(user.accessLevel, "free");
    assert.equal(user.subscriptionStatus, expectedStatus);
  }
});

test("RTDN never revokes a newer Stripe or Paystack entitlement", async () => {
  const firestore = createFirestore();
  const purchaseToken = "superseded-play-token";
  const initial = activeSubscription();
  await activateGooglePlaySubscription({
    firestore,
    userEmail: "multi-provider@example.com",
    userUid: "firebase-user-1",
    purchaseToken,
    productId: PREMIUM_YEARLY_PRODUCT_ID,
    subscription: initial,
    verified: validateGooglePlaySubscription(initial, {
      expectedAccountId: googlePlayAccountId("firebase-user-1"),
    }),
    source: "purchase",
  });
  firestore.documents.set("users/multi-provider@example.com", {
    ...firestore.documents.get("users/multi-provider@example.com"),
    accessLevel: "premium",
    subscriptionStatus: "active",
    subscriptionProvider: "stripe",
    subscriptionReference: "sub_newer_stripe",
  });
  const expired = activeSubscription({
    overrides: {
      subscriptionState: "SUBSCRIPTION_STATE_EXPIRED",
      lineItems: [{
        productId: PREMIUM_YEARLY_PRODUCT_ID,
        expiryTime: "2026-07-22T00:00:00Z",
      }],
    },
  });
  const handler = createGooglePlayRtdnHandler({
    firestore,
    fetchSubscription: async () => expired,
  });

  const result = await handler(rtdnEvent({
    messageId: "superseded-event",
    notificationType: 13,
    purchaseToken,
  }));
  const user = firestore.documents.get("users/multi-provider@example.com");
  assert.equal(result.reason, "superseded_entitlement");
  assert.equal(user.accessLevel, "premium");
  assert.equal(user.subscriptionProvider, "stripe");
});

test("RTDN safely records a purchase that has not reached the app yet", async () => {
  const firestore = createFirestore();
  const handler = createGooglePlayRtdnHandler({
    firestore,
    fetchSubscription: async () => activeSubscription(),
  });

  const result = await handler(rtdnEvent({
    messageId: "orphan-purchase-event",
    notificationType: 4,
    purchaseToken: "not-yet-registered",
  }));
  assert.equal(result.ignored, true);
  assert.equal(result.reason, "unknown_purchase");
  assert.equal(
      firestore.documents.has("users/reader@example.com"),
      false,
  );
});

test("scheduled reconciliation refreshes renewal and expiry without Pub/Sub", async () => {
  const firestore = createFirestore();
  const renewalToken = "scheduled-renewal-token";
  const expiryToken = "scheduled-expiry-token";

  for (const [email, token] of [
    ["renewal@example.com", renewalToken],
    ["expiry@example.com", expiryToken],
  ]) {
    const initial = activeSubscription();
    await activateGooglePlaySubscription({
      firestore,
      userEmail: email,
      userUid: "firebase-user-1",
      purchaseToken: token,
      productId: PREMIUM_YEARLY_PRODUCT_ID,
      subscription: initial,
      verified: validateGooglePlaySubscription(initial, {
        expectedAccountId: googlePlayAccountId("firebase-user-1"),
      }),
      source: "purchase",
    });
  }

  const purchases = [renewalToken, expiryToken].map((token) => ({
    data: () => firestore.documents.get(
        `google_play_subscription_purchases/${purchaseTokenHash(token)}`,
    ),
  }));
  const handler = createGooglePlayReconciliationHandler({
    firestore,
    loadPurchases: async () => purchases,
    fetchSubscription: async ({purchaseToken}) => purchaseToken === renewalToken ?
      activeSubscription({
        overrides: {
          lineItems: [{
            productId: PREMIUM_YEARLY_PRODUCT_ID,
            expiryTime: "2028-07-23T00:00:00Z",
            autoRenewingPlan: {autoRenewEnabled: true},
          }],
        },
      }) :
      activeSubscription({
        overrides: {
          subscriptionState: "SUBSCRIPTION_STATE_EXPIRED",
          lineItems: [{
            productId: PREMIUM_YEARLY_PRODUCT_ID,
            expiryTime: "2026-07-22T00:00:00Z",
          }],
        },
      }),
  });

  const result = await handler();
  const renewedUser = firestore.documents.get("users/renewal@example.com");
  const expiredUser = firestore.documents.get("users/expiry@example.com");
  assert.deepEqual(result, {
    checkedCount: 2,
    updatedCount: 2,
    activeCount: 1,
    inactiveCount: 1,
    skippedCount: 0,
    failedCount: 0,
  });
  assert.equal(
      renewedUser.subscriptionExpiresAt.toISOString(),
      "2028-07-23T00:00:00.000Z",
  );
  assert.equal(expiredUser.accessLevel, "free");
  assert.equal(expiredUser.subscriptionStatus, "expired");
});

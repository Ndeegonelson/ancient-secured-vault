const test = require("node:test");
const assert = require("node:assert/strict");

const {
  ANDROID_PUBLISHER_SCOPE,
  PREMIUM_YEARLY_PRODUCT_ID,
  activateGooglePlaySubscription,
  createAndroidPublisherAuth,
  createVerifyGooglePlayPurchaseHandler,
  googleAccessToken,
  googlePlayAccountId,
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

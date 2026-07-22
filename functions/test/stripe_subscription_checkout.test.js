const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createStripeBillingPortalSessionHandler,
  createStripeCheckoutSessionHandler,
  handleStripeEvent,
  validateStripePremiumPrice,
} = require("../stripe_subscription_checkout");

class FakeFirestore {
  constructor() {
    this.collections = new Map();
    this.generatedIds = new Map();
  }

  collection(name) {
    if (!this.collections.has(name)) {
      this.collections.set(name, new Map());
    }
    const docs = this.collections.get(name);
    return {
      doc: (id) => {
        const safeId = id || this.nextId(name);
        return new FakeDocumentReference(safeId, docs);
      },
      where: (field, operator, value) => {
        assert.equal(operator, "==");
        return {
          limit: (count) => ({
            get: async () => {
              const matches = [...docs.entries()]
                  .filter(([, data]) => data && data[field] === value)
                  .slice(0, count)
                  .map(([id, data]) => ({
                    id,
                    data: () => data,
                  }));
              return {docs: matches};
            },
          }),
        };
      },
    };
  }

  nextId(name) {
    const current = this.generatedIds.get(name) || 0;
    const next = current + 1;
    this.generatedIds.set(name, next);
    return `${name}-${next}`;
  }

  data(collection, id) {
    return this.collections.get(collection).get(id);
  }
}

class FakeDocumentReference {
  constructor(id, docs) {
    this.id = id;
    this.docs = docs;
  }

  async set(data, options = {}) {
    const current = options.merge ? this.docs.get(this.id) || {} : {};
    this.docs.set(this.id, {...current, ...data});
  }

  async update(data) {
    const current = this.docs.get(this.id) || {};
    this.docs.set(this.id, {...current, ...data});
  }

  async get() {
    const data = this.docs.get(this.id);
    return {
      exists: data !== undefined,
      data: () => data,
    };
  }
}

function fakeResponse() {
  return {
    statusCode: 200,
    headers: {},
    body: undefined,
    set(name, value) {
      this.headers[name] = value;
    },
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
    send(body) {
      this.body = body;
      return this;
    },
  };
}

function fakeRequest({
  method = "POST",
  body = {},
  authorization = "Bearer user-token",
  origin = "https://app.test",
} = {}) {
  return {
    method,
    body,
    get(name) {
      const key = name.toLowerCase();
      if (key === "authorization") return authorization;
      if (key === "origin") return origin;
      return "";
    },
  };
}

test("creates a Stripe checkout session and records the request", async () => {
  const firestore = new FakeFirestore();
  let capturedSessionPayload;
  const stripe = {
    prices: {
      retrieve: async (priceId) => ({
        id: priceId,
        active: true,
        unit_amount: 10000,
        currency: "usd",
        recurring: {interval: "year", interval_count: 1},
      }),
    },
    checkout: {
      sessions: {
        create: async (payload) => {
          capturedSessionPayload = payload;
          return {
            id: "cs_test_123",
            url: "https://checkout.stripe.com/c/pay/cs_test_123",
          };
        },
      },
    },
  };
  const handler = createStripeCheckoutSessionHandler({
    firestore,
    verifyAuthToken: async () => ({
      uid: "reader-1",
      email: "Reader@Example.COM",
    }),
    stripeClientFactory: () => stripe,
    getPriceId: () => "price_test_premium",
    getAppBaseUrl: () => "https://app.test",
  });
  const response = fakeResponse();

  await handler(
      fakeRequest({
        body: {
          data: {
            message: " Premium access ",
            successUrl: "https://app.test/success",
            cancelUrl: "https://app.test/cancel",
          },
        },
      }),
      response,
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, {
    requestId: "user_subscription_requests-1",
    checkoutUrl: "https://checkout.stripe.com/c/pay/cs_test_123",
  });
  assert.equal(capturedSessionPayload.mode, "subscription");
  assert.equal(capturedSessionPayload.customer_email, "reader@example.com");
  assert.deepEqual(capturedSessionPayload.line_items, [{
    price: "price_test_premium",
    quantity: 1,
  }]);
  assert.equal(
      capturedSessionPayload.metadata.subscriptionRequestId,
      "user_subscription_requests-1",
  );
  assert.deepEqual(capturedSessionPayload.subscription_data.metadata, {
    subscriptionRequestId: "user_subscription_requests-1",
    userEmail: "reader@example.com",
    requestedPlan: "premium",
    source: "stripe_checkout",
  });
  assert.equal(
      firestore.data("user_subscription_requests", "user_subscription_requests-1")
          .paymentReference,
      "cs_test_123",
  );
});

test("Stripe checkout rejects a price that is not USD 100 yearly", async () => {
  const firestore = new FakeFirestore();
  let checkoutWasCreated = false;
  const handler = createStripeCheckoutSessionHandler({
    firestore,
    verifyAuthToken: async () => ({
      uid: "reader-1",
      email: "reader@example.com",
    }),
    stripeClientFactory: () => ({
      prices: {
        retrieve: async () => ({
          active: true,
          unit_amount: 12000,
          currency: "usd",
          recurring: {interval: "year", interval_count: 1},
        }),
      },
      checkout: {
        sessions: {
          create: async () => {
            checkoutWasCreated = true;
            return {id: "cs_wrong", url: "https://checkout.test"};
          },
        },
      },
    }),
    getPriceId: () => "price_wrong",
    getAppBaseUrl: () => "https://app.test",
  });
  const response = fakeResponse();

  await handler(fakeRequest(), response);

  assert.equal(response.statusCode, 500);
  assert.equal(checkoutWasCreated, false);
  assert.match(response.body.error.message, /USD 100 yearly/i);
});

test("Stripe premium price validation accepts the canonical annual price", () => {
  assert.doesNotThrow(() => validateStripePremiumPrice({
    active: true,
    unit_amount: 10000,
    currency: "usd",
    recurring: {interval: "year", interval_count: 1},
  }));
});

test("active premium users cannot start a Stripe checkout", async () => {
  const firestore = new FakeFirestore();
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      .toISOString();
  await firestore.collection("users").doc("reader@example.com").set({
    email: "reader@example.com",
    accessLevel: "premium",
    subscriptionStatus: "active",
    subscriptionExpiresAt: futureExpiry,
  });
  let checkoutWasCreated = false;
  const handler = createStripeCheckoutSessionHandler({
    firestore,
    verifyAuthToken: async () => ({
      uid: "reader-1",
      email: "reader@example.com",
    }),
    stripeClientFactory: () => ({
      checkout: {
        sessions: {
          create: async () => {
            checkoutWasCreated = true;
            return {id: "cs_test_blocked", url: "https://checkout.test"};
          },
        },
      },
    }),
    getPriceId: () => "price_test_premium",
    getAppBaseUrl: () => "https://app.test",
  });
  const response = fakeResponse();

  await handler(fakeRequest(), response);

  assert.equal(response.statusCode, 409);
  assert.equal(checkoutWasCreated, false);
  assert.match(response.body.error.message, /already active/i);
});

test("completed checkout approves the request and activates user access", async () => {
  const firestore = new FakeFirestore();

  await handleStripeEvent({
    firestore,
    event: {
      id: "evt_checkout_complete",
      type: "checkout.session.completed",
      data: {
        object: {
          id: "cs_test_123",
          customer: "cus_test_123",
          subscription: "sub_test_123",
          customer_email: "reader@example.com",
          metadata: {
            subscriptionRequestId: "request-1",
            userEmail: "reader@example.com",
            requestedPlan: "premium",
          },
        },
      },
    },
  });

  assert.equal(
      firestore.data("user_subscription_requests", "request-1").status,
      "approved",
  );
  assert.equal(
      firestore.data("user_subscription_requests", "request-1").paymentStatus,
      "confirmed",
  );
  assert.equal(
      firestore.data("users", "reader@example.com").subscriptionStatus,
      "active",
  );
  assert.equal(
      firestore.data("users", "reader@example.com").subscriptionProvider,
      "stripe",
  );
  assert.equal(
      firestore.data("payment_webhook_events", "stripe_evt_checkout_complete")
          .status,
      "processed",
  );
  assert.equal(
      firestore.data("payment_webhook_events", "stripe_evt_checkout_complete")
          .requestId,
      "request-1",
  );
});

test("duplicate Stripe checkout webhooks are ignored after processing", async () => {
  const firestore = new FakeFirestore();
  const event = {
    id: "evt_duplicate_checkout",
    type: "checkout.session.completed",
    data: {
      object: {
        id: "cs_test_123",
        customer: "cus_test_123",
        subscription: "sub_test_123",
        customer_email: "reader@example.com",
        metadata: {
          subscriptionRequestId: "request-1",
          userEmail: "reader@example.com",
          requestedPlan: "premium",
        },
      },
    },
  };

  await handleStripeEvent({firestore, event});
  await firestore.collection("user_subscription_requests").doc("request-1").set({
    status: "already-reviewed",
  }, {merge: true});
  await firestore.collection("users").doc("reader@example.com").set({
    subscriptionStatus: "already-active",
  }, {merge: true});

  await handleStripeEvent({firestore, event});

  assert.equal(
      firestore.data("user_subscription_requests", "request-1").status,
      "already-reviewed",
  );
  assert.equal(
      firestore.data("users", "reader@example.com").subscriptionStatus,
      "already-active",
  );
});

test("updated active subscription keeps premium vault access", async () => {
  const firestore = new FakeFirestore();

  await handleStripeEvent({
    firestore,
    event: {
      type: "customer.subscription.updated",
      data: {
        object: {
          id: "sub_test_123",
          customer: "cus_test_123",
          status: "active",
          current_period_end: 1790000000,
          metadata: {
            userEmail: "reader@example.com",
          },
        },
      },
    },
  });

  const access = firestore.data("users", "reader@example.com");
  assert.equal(access.accessLevel, "premium");
  assert.equal(access.subscriptionStatus, "active");
  assert.equal(access.stripeSubscriptionStatus, "active");
  assert.equal(access.stripeSubscriptionId, "sub_test_123");
  assert.ok(access.subscriptionExpiresAt instanceof Date);
});

test("deleted subscription removes protected vault access", async () => {
  const firestore = new FakeFirestore();
  await firestore.collection("users").doc("reader@example.com").set({
    email: "reader@example.com",
    accessLevel: "premium",
    subscriptionStatus: "active",
    stripeCustomerId: "cus_test_123",
    stripeSubscriptionId: "sub_test_123",
  });

  await handleStripeEvent({
    firestore,
    event: {
      type: "customer.subscription.deleted",
      data: {
        object: {
          id: "sub_test_123",
          customer: "cus_test_123",
          status: "canceled",
        },
      },
    },
  });

  const access = firestore.data("users", "reader@example.com");
  assert.equal(access.accessLevel, "free");
  assert.equal(access.subscriptionStatus, "cancelled");
  assert.equal(access.subscriptionProvider, "stripe");
});

test("failed invoice records the Stripe payment issue", async () => {
  const firestore = new FakeFirestore();
  await firestore.collection("users").doc("reader@example.com").set({
    email: "reader@example.com",
    accessLevel: "premium",
    subscriptionStatus: "active",
    stripeCustomerId: "cus_test_123",
    stripeSubscriptionId: "sub_test_123",
  });

  await handleStripeEvent({
    firestore,
    event: {
      type: "invoice.payment_failed",
      data: {
        object: {
          id: "in_test_123",
          customer: "cus_test_123",
          subscription: "sub_test_123",
        },
      },
    },
  });

  const access = firestore.data("users", "reader@example.com");
  assert.equal(access.stripeLastInvoiceId, "in_test_123");
  assert.equal(access.stripeLastPaymentStatus, "failed");
});

test("creates a Stripe billing portal session for a Stripe subscriber", async () => {
  const firestore = new FakeFirestore();
  await firestore.collection("users").doc("reader@example.com").set({
    email: "reader@example.com",
    accessLevel: "premium",
    subscriptionStatus: "active",
    stripeCustomerId: "cus_test_123",
  });
  let capturedPortalPayload;
  const stripe = {
    billingPortal: {
      sessions: {
        create: async (payload) => {
          capturedPortalPayload = payload;
          return {
            url: "https://billing.stripe.com/p/session/test",
          };
        },
      },
    },
  };
  const handler = createStripeBillingPortalSessionHandler({
    firestore,
    verifyAuthToken: async () => ({
      uid: "reader-1",
      email: "Reader@Example.COM",
    }),
    stripeClientFactory: () => stripe,
    getAppBaseUrl: () => "https://app.test",
  });
  const response = fakeResponse();

  await handler(
      fakeRequest({
        body: {
          data: {
            returnUrl: "https://app.test/dashboard",
          },
        },
      }),
      response,
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, {
    portalUrl: "https://billing.stripe.com/p/session/test",
  });
  assert.deepEqual(capturedPortalPayload, {
    customer: "cus_test_123",
    return_url: "https://app.test/dashboard",
  });
});

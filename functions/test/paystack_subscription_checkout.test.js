const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createPaystackCheckoutSessionHandler,
  handlePaystackEvent,
  validatePaystackPremiumCharge,
} = require("../paystack_subscription_checkout");

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

test("creates a Paystack checkout session and records the request", async () => {
  const firestore = new FakeFirestore();
  let capturedPayload;
  const fetchImpl = async (url, options) => {
    assert.equal(url, "https://api.paystack.co/transaction/initialize");
    capturedPayload = JSON.parse(options.body);
    return {
      ok: true,
      status: 200,
      json: async () => ({
        status: true,
        data: {
          authorization_url: "https://checkout.paystack.com/test",
          reference: "paystack-ref-1",
        },
      }),
    };
  };
  const handler = createPaystackCheckoutSessionHandler({
    firestore,
    fetchImpl,
    verifyAuthToken: async () => ({
      uid: "reader-1",
      email: "Reader@Example.COM",
    }),
    getSecretKey: () => "sk_test_paystack",
    getAmountSubunits: () => "10000",
    getCurrency: () => "USD",
    getAppBaseUrl: () => "https://app.test",
  });
  const response = fakeResponse();

  await handler(
      fakeRequest({
        body: {
          data: {
            message: " Premium access ",
            successUrl: "https://app.test/success",
          },
        },
      }),
      response,
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, {
    requestId: "user_subscription_requests-1",
    checkoutUrl: "https://checkout.paystack.com/test",
  });
  assert.equal(capturedPayload.email, "reader@example.com");
  assert.equal(capturedPayload.amount, 10000);
  assert.equal(capturedPayload.currency, "USD");
  assert.equal(capturedPayload.callback_url, "https://app.test/success");
  assert.deepEqual(capturedPayload.metadata, {
    subscriptionRequestId: "user_subscription_requests-1",
    userEmail: "reader@example.com",
    requestedPlan: "premium",
    source: "paystack_checkout",
  });
  assert.equal(
      firestore.data("user_subscription_requests", "user_subscription_requests-1")
          .paystackReference,
      "paystack-ref-1",
  );
});

test("active premium users cannot start a Paystack checkout", async () => {
  const firestore = new FakeFirestore();
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      .toISOString();
  await firestore.collection("users").doc("reader@example.com").set({
    email: "reader@example.com",
    accessLevel: "premium",
    subscriptionStatus: "active",
    subscriptionExpiresAt: futureExpiry,
  });
  let paystackWasCalled = false;
  const handler = createPaystackCheckoutSessionHandler({
    firestore,
    fetchImpl: async () => {
      paystackWasCalled = true;
      return {
        ok: true,
        status: 200,
        json: async () => ({status: true, data: {}}),
      };
    },
    verifyAuthToken: async () => ({
      uid: "reader-1",
      email: "reader@example.com",
    }),
    getSecretKey: () => "sk_test_paystack",
    getAmountSubunits: () => "10000",
    getCurrency: () => "USD",
    getAppBaseUrl: () => "https://app.test",
  });
  const response = fakeResponse();

  await handler(fakeRequest(), response);

  assert.equal(response.statusCode, 409);
  assert.equal(paystackWasCalled, false);
  assert.match(response.body.error.message, /already active/i);
});

test("successful Paystack charge approves request and activates access", async () => {
  const firestore = new FakeFirestore();
  const fetchImpl = async (url) => {
    assert.equal(
        url,
        "https://api.paystack.co/transaction/verify/paystack-ref-1",
    );
    return {
      ok: true,
      status: 200,
      json: async () => ({
        status: true,
        data: {
          status: "success",
          reference: "paystack-ref-1",
          amount: 10000,
          currency: "USD",
          paid_at: "2026-06-13T10:00:00.000Z",
          customer: {
            email: "reader@example.com",
            customer_code: "CUS_test",
          },
          metadata: {
            subscriptionRequestId: "request-1",
            userEmail: "reader@example.com",
            requestedPlan: "premium",
          },
        },
      }),
    };
  };

  await handlePaystackEvent({
    firestore,
    fetchImpl,
    secretKey: "sk_test_paystack",
    event: {
      event: "charge.success",
      data: {
        id: "paystack-event-1",
        reference: "paystack-ref-1",
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
  const access = firestore.data("users", "reader@example.com");
  assert.equal(access.accessLevel, "premium");
  assert.equal(access.subscriptionStatus, "active");
  assert.equal(access.subscriptionProvider, "paystack");
  assert.equal(access.paystackReference, "paystack-ref-1");
  assert.ok(access.subscriptionExpiresAt instanceof Date);
  assert.equal(
      access.subscriptionExpiresAt.toISOString(),
      "2027-06-13T10:00:00.000Z",
  );
  assert.equal(
      firestore.data("payment_webhook_events", "paystack_paystack-event-1")
          .status,
      "processed",
  );
  assert.equal(
      firestore.data("payment_webhook_events", "paystack_paystack-event-1")
          .requestId,
      "request-1",
  );
});

test("successful Paystack charge without paid_at still sets a renewal date", async () => {
  const firestore = new FakeFirestore();
  const fetchImpl = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      status: true,
      data: {
        status: "success",
        reference: "paystack-ref-no-date",
        amount: 10000,
        currency: "USD",
        customer: {
          email: "reader@example.com",
          customer_code: "CUS_test",
        },
        metadata: {
          subscriptionRequestId: "request-1",
          userEmail: "reader@example.com",
          requestedPlan: "premium",
        },
      },
    }),
  });

  await handlePaystackEvent({
    firestore,
    fetchImpl,
    secretKey: "sk_test_paystack",
    event: {
      event: "charge.success",
      data: {
        id: "paystack-event-no-date",
        reference: "paystack-ref-no-date",
      },
    },
  });

  const access = firestore.data("users", "reader@example.com");
  assert.equal(access.subscriptionProvider, "paystack");
  assert.ok(access.subscriptionExpiresAt instanceof Date);
  assert.ok(access.subscriptionExpiresAt.getTime() > Date.now());
});

test("duplicate Paystack charge webhooks do not re-verify or re-approve", async () => {
  const firestore = new FakeFirestore();
  let verifyCount = 0;
  const fetchImpl = async () => {
    verifyCount += 1;
    return {
      ok: true,
      status: 200,
      json: async () => ({
        status: true,
        data: {
          status: "success",
          reference: "paystack-ref-1",
          amount: 10000,
          currency: "USD",
          paid_at: "2026-06-13T10:00:00.000Z",
          customer: {
            email: "reader@example.com",
            customer_code: "CUS_test",
          },
          metadata: {
            subscriptionRequestId: "request-1",
            userEmail: "reader@example.com",
            requestedPlan: "premium",
          },
        },
      }),
    };
  };
  const event = {
    event: "charge.success",
    data: {
      id: "paystack-event-1",
      reference: "paystack-ref-1",
    },
  };

  await handlePaystackEvent({
    firestore,
    fetchImpl,
    secretKey: "sk_test_paystack",
    event,
  });
  await firestore.collection("user_subscription_requests").doc("request-1").set({
    status: "already-reviewed",
  }, {merge: true});

  await handlePaystackEvent({
    firestore,
    fetchImpl,
    secretKey: "sk_test_paystack",
    event,
  });

  assert.equal(verifyCount, 1);
  assert.equal(
      firestore.data("user_subscription_requests", "request-1").status,
      "already-reviewed",
  );
});

test("Paystack premium activation rejects the wrong amount or currency", () => {
  assert.throws(
      () => validatePaystackPremiumCharge({
        charge: {amount: 9999, currency: "USD"},
      }),
      /does not match the premium annual price/i,
  );
  assert.throws(
      () => validatePaystackPremiumCharge({
        charge: {amount: 10000, currency: "GHS"},
      }),
      /does not match the premium annual price/i,
  );
});

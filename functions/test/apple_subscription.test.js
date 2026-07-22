const test = require("node:test");
const assert = require("node:assert/strict");

const {
  PREMIUM_YEARLY_PRODUCT_ID,
  activateAppleSubscription,
  validatePremiumTransaction,
} = require("../apple_subscription");

function activeTransaction(overrides = {}) {
  return {
    productId: PREMIUM_YEARLY_PRODUCT_ID,
    transactionId: "200000000000001",
    originalTransactionId: "200000000000000",
    purchaseDate: Date.now() - 60_000,
    expiresDate: Date.now() + 365 * 24 * 60 * 60 * 1000,
    ...overrides,
  };
}

function createFirestore() {
  const documents = new Map();
  const writes = [];

  function reference(collection, id) {
    return {collection, id, key: `${collection}/${id}`};
  }

  return {
    documents,
    writes,
    collection(name) {
      return {
        doc(id) {
          return reference(name, id);
        },
      };
    },
    async runTransaction(callback) {
      await callback({
        async get(ref) {
          const data = documents.get(ref.key);
          return {
            exists: Boolean(data),
            data: () => data,
          };
        },
        set(ref, data, options) {
          const previous = documents.get(ref.key) || {};
          documents.set(
              ref.key,
              options && options.merge ? {...previous, ...data} : data,
          );
          writes.push({ref, data, options});
        },
      });
    },
  };
}

test("validates an active premium App Store transaction", () => {
  const expiresAt = validatePremiumTransaction(activeTransaction());
  assert.ok(expiresAt instanceof Date);
  assert.ok(expiresAt.getTime() > Date.now());
});

test("rejects expired or unrelated App Store transactions", () => {
  assert.throws(
      () => validatePremiumTransaction(activeTransaction({expiresDate: 1})),
      /expired/i,
  );
  assert.throws(
      () => validatePremiumTransaction(activeTransaction({
        productId: "unrelated.product",
      })),
      /does not unlock premium/i,
  );
});

test("activates premium only after verified Apple transaction delivery", async () => {
  const firestore = createFirestore();
  const result = await activateAppleSubscription({
    firestore,
    userEmail: "reader@example.com",
    environment: "sandbox",
    transaction: activeTransaction(),
    source: "purchase",
  });

  assert.equal(result.subscriptionProvider, "app_store");
  assert.equal(result.subscriptionStatus, "active");
  const user = firestore.documents.get("users/reader@example.com");
  assert.equal(user.accessLevel, "premium");
  assert.equal(user.appleOriginalTransactionId, "200000000000000");
});

test("prevents one Apple transaction from activating two accounts", async () => {
  const firestore = createFirestore();
  const transaction = activeTransaction();
  await activateAppleSubscription({
    firestore,
    userEmail: "first@example.com",
    environment: "sandbox",
    transaction,
    source: "purchase",
  });

  await assert.rejects(
      activateAppleSubscription({
        firestore,
        userEmail: "second@example.com",
        environment: "sandbox",
        transaction,
        source: "restore",
      }),
      /belongs to another account/i,
  );
});

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  expireDueSubscriptions,
  shouldExpireUser,
} = require("../subscription_expiry_maintenance");

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
    return new FakeCollectionReference(name, docs, this);
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

  collectionData(collection) {
    return [...(this.collections.get(collection) || new Map()).values()];
  }
}

class FakeCollectionReference {
  constructor(name, docs, firestore) {
    this.name = name;
    this.docs = docs;
    this.firestore = firestore;
    this.filters = [];
    this.resultLimit = Infinity;
  }

  doc(id) {
    const safeId = id || this.firestore.nextId(this.name);
    return new FakeDocumentReference(safeId, this.docs);
  }

  where(field, operator, value) {
    assert.equal(operator, "<=");
    const clone = this.clone();
    clone.filters.push({field, value});
    return clone;
  }

  limit(count) {
    const clone = this.clone();
    clone.resultLimit = count;
    return clone;
  }

  async get() {
    const matches = [...this.docs.entries()]
        .filter(([, data]) => this.matchesFilters(data))
        .slice(0, this.resultLimit)
        .map(([id, data]) => ({
          id,
          ref: new FakeDocumentReference(id, this.docs),
          data: () => data,
        }));
    return {docs: matches};
  }

  matchesFilters(data) {
    return this.filters.every(({field, value}) => {
      const left = data[field];
      if (left instanceof Date && value instanceof Date) {
        return left.getTime() <= value.getTime();
      }
      return left <= value;
    });
  }

  clone() {
    const clone = new FakeCollectionReference(
        this.name,
        this.docs,
        this.firestore,
    );
    clone.filters = [...this.filters];
    clone.resultLimit = this.resultLimit;
    return clone;
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
}

test("identifies only admin-managed expired subscriptions", () => {
  const now = new Date("2026-06-14T12:00:00.000Z");

  assert.equal(shouldExpireUser({
    role: "reader",
    subscriptionStatus: "active",
    subscriptionProvider: "paystack",
    subscriptionExpiresAt: new Date("2026-06-14T11:00:00.000Z"),
  }, now), true);
  assert.equal(shouldExpireUser({
    role: "reader",
    subscriptionStatus: "active",
    subscriptionProvider: "stripe",
    subscriptionExpiresAt: new Date("2026-06-14T11:00:00.000Z"),
  }, now), false);
  assert.equal(shouldExpireUser({
    role: "admin",
    subscriptionStatus: "active",
    subscriptionProvider: "manual",
    subscriptionExpiresAt: new Date("2026-06-14T11:00:00.000Z"),
  }, now), false);
  assert.equal(shouldExpireUser({
    role: "reader",
    subscriptionStatus: "active",
    subscriptionProvider: "manual",
    subscriptionExpiresAt: new Date("2026-06-15T12:00:00.000Z"),
  }, now), false);
});

test("expires due admin-managed subscriptions and writes audit logs", async () => {
  const firestore = new FakeFirestore();
  await firestore.collection("users").doc("paystack@example.com").set({
    email: "paystack@example.com",
    role: "reader",
    accessLevel: "premium",
    subscriptionStatus: "active",
    subscriptionProvider: "paystack",
    subscriptionExpiresAt: new Date("2026-06-13T12:00:00.000Z"),
  });
  await firestore.collection("users").doc("manual@example.com").set({
    email: "manual@example.com",
    role: "reader",
    accessLevel: "premium",
    subscriptionStatus: "trial",
    subscriptionProvider: "manual",
    subscriptionExpiresAt: new Date("2026-06-14T12:00:00.000Z"),
  });
  await firestore.collection("users").doc("stripe@example.com").set({
    email: "stripe@example.com",
    role: "reader",
    accessLevel: "premium",
    subscriptionStatus: "active",
    subscriptionProvider: "stripe",
    subscriptionExpiresAt: new Date("2026-06-13T12:00:00.000Z"),
  });

  const result = await expireDueSubscriptions({
    firestore,
    now: new Date("2026-06-14T12:00:00.000Z"),
  });

  assert.equal(result.checkedCount, 3);
  assert.equal(result.expiredCount, 2);
  assert.deepEqual(result.expiredUsers, [
    "paystack@example.com",
    "manual@example.com",
  ]);
  assert.equal(
      firestore.data("users", "paystack@example.com").accessLevel,
      "free",
  );
  assert.equal(
      firestore.data("users", "paystack@example.com").subscriptionStatus,
      "expired",
  );
  assert.equal(
      firestore.data("users", "manual@example.com").subscriptionStatus,
      "expired",
  );
  assert.equal(
      firestore.data("users", "stripe@example.com").subscriptionStatus,
      "active",
  );

  const auditLogs = firestore.collectionData("user_subscription_audit_logs");
  assert.equal(auditLogs.length, 2);
  assert.equal(auditLogs[0].changedByEmail, "system");
  assert.equal(auditLogs[0].nextSubscriptionStatus, "expired");
  assert.equal(auditLogs[0].subscriptionChangeType, "expiry_enforcement");
});

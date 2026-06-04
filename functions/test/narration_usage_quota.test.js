const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createNarrationUsageQuota,
  usageDocumentId,
  utcDateKey,
} = require("../narration_usage_quota");

const premiumAccess = {
  role: "reader",
  subscriptionStatus: "active",
};
const adminAccess = {
  role: "admin",
  subscriptionStatus: "inactive",
};
const limits = {
  premium: {characters: 10, requests: 2},
  admin: {characters: 30, requests: 4},
};

class FakeFirestore {
  constructor() {
    this.documents = new Map();
    this.transactionTail = Promise.resolve();
  }

  collection(name) {
    return {
      doc: (id) => ({path: `${name}/${id}`}),
    };
  }

  async runTransaction(operation) {
    const previous = this.transactionTail;
    let release;
    this.transactionTail = new Promise((resolve) => {
      release = resolve;
    });
    await previous;

    const transaction = {
      get: async (reference) => {
        const value = this.documents.get(reference.path);
        return {
          exists: value !== undefined,
          data: () => value,
        };
      },
      set: (reference, value) => {
        this.documents.set(reference.path, {
          ...(this.documents.get(reference.path) || {}),
          ...value,
        });
      },
    };

    try {
      return await operation(transaction);
    } finally {
      release();
    }
  }
}

function createQuota(firestore, date = new Date("2026-06-04T12:00:00Z")) {
  return createNarrationUsageQuota({
    firestore,
    dailyLimits: limits,
    now: () => date,
    serverTimestamp: () => "server-time",
  });
}

function expectHttpsCode(code) {
  return (error) => {
    assert.equal(error.code, code);
    return true;
  };
}

test("premium usage is recorded and remaining allowance is returned", async () => {
  const firestore = new FakeFirestore();
  const quota = createQuota(firestore);

  const result = await quota.consume({
    uid: "reader-123",
    access: premiumAccess,
    characterCount: 6,
  });

  assert.deepEqual(result, {
    dateKey: "2026-06-04",
    plan: "premium",
    usedCharacters: 6,
    usedRequests: 1,
    remainingCharacters: 4,
    remainingRequests: 1,
  });
});

test("daily limits reject excess work without changing stored usage", async () => {
  const firestore = new FakeFirestore();
  const quota = createQuota(firestore);

  await quota.consume({
    uid: "reader-123",
    access: premiumAccess,
    characterCount: 7,
  });
  await assert.rejects(
      quota.consume({
        uid: "reader-123",
        access: premiumAccess,
        characterCount: 4,
      }),
      expectHttpsCode("resource-exhausted"),
  );

  const stored = [...firestore.documents.values()][0];
  assert.equal(stored.characterCount, 7);
  assert.equal(stored.requestCount, 1);
});

test("request-count limits block repeated tiny synthesis calls", async () => {
  const firestore = new FakeFirestore();
  const quota = createQuota(firestore);

  await quota.consume({
    uid: "reader-123",
    access: premiumAccess,
    characterCount: 1,
  });
  await quota.consume({
    uid: "reader-123",
    access: premiumAccess,
    characterCount: 1,
  });
  await assert.rejects(
      quota.consume({
        uid: "reader-123",
        access: premiumAccess,
        characterCount: 1,
      }),
      expectHttpsCode("resource-exhausted"),
  );

  const stored = [...firestore.documents.values()][0];
  assert.equal(stored.characterCount, 2);
  assert.equal(stored.requestCount, 2);
});

test("simultaneous requests cannot both cross the atomic daily limit", async () => {
  const firestore = new FakeFirestore();
  const quota = createQuota(firestore);

  const results = await Promise.allSettled([
    quota.consume({
      uid: "reader-123",
      access: premiumAccess,
      characterCount: 6,
    }),
    quota.consume({
      uid: "reader-123",
      access: premiumAccess,
      characterCount: 6,
    }),
  ]);

  assert.equal(
      results.filter((result) => result.status === "fulfilled").length,
      1,
  );
  assert.equal(
      results.filter((result) => result.status === "rejected").length,
      1,
  );
  const stored = [...firestore.documents.values()][0];
  assert.equal(stored.characterCount, 6);
  assert.equal(stored.requestCount, 1);
});

test("admin allowance is larger but still cost protected", async () => {
  const firestore = new FakeFirestore();
  const quota = createQuota(firestore);

  const result = await quota.consume({
    uid: "admin-123",
    access: adminAccess,
    characterCount: 20,
  });

  assert.equal(result.plan, "admin");
  assert.equal(result.remainingCharacters, 10);
  assert.equal(result.remainingRequests, 3);
});

test("usage record identifiers do not expose the Firebase user id", () => {
  const id = usageDocumentId("private-reader-identity", "2026-06-04");

  assert.doesNotMatch(id, /private-reader-identity/);
  assert.match(id, /^[a-f0-9]{64}_2026-06-04$/);
});

test("usage resets into a separate UTC day record", async () => {
  const firestore = new FakeFirestore();
  const firstQuota = createQuota(
      firestore,
      new Date("2026-06-04T23:59:59Z"),
  );
  const nextQuota = createQuota(
      firestore,
      new Date("2026-06-05T00:00:00Z"),
  );

  await firstQuota.consume({
    uid: "reader-123",
    access: premiumAccess,
    characterCount: 10,
  });
  const result = await nextQuota.consume({
    uid: "reader-123",
    access: premiumAccess,
    characterCount: 4,
  });

  assert.equal(result.dateKey, "2026-06-05");
  assert.equal(result.usedCharacters, 4);
  assert.equal(firestore.documents.size, 2);
});

test("corrupt stored counters fail closed instead of resetting usage", async () => {
  const firestore = new FakeFirestore();
  const quota = createQuota(firestore);
  const usageId = usageDocumentId("reader-123", "2026-06-04");
  firestore.documents.set(`cloud_narration_usage/${usageId}`, {
    characterCount: "invalid",
    requestCount: 1,
  });

  await assert.rejects(
      quota.consume({
        uid: "reader-123",
        access: premiumAccess,
        characterCount: 1,
      }),
      expectHttpsCode("internal"),
  );
});

test("UTC date keys reject invalid server clocks", () => {
  assert.throws(() => utcDateKey(new Date("invalid")), TypeError);
});

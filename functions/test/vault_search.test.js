const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createVaultSearchHandler,
  canOpenPdfWithAccessLevel,
  vaultPrimarySearchTerm,
  vaultSearchQueryTerms,
  vaultSearchTerms,
} = require("../vault_search");

test("vault search terms normalize and rank searchable words", () => {
  assert.deepEqual(
      vaultSearchTerms("  Ancient Wealth Architecture!!! money money  "),
      ["architecture", "ancient", "wealth", "money"],
  );
});

test("vault primary search term returns the strongest searchable word", () => {
  assert.equal(
      vaultPrimarySearchTerm("The Untaught History of Money"),
      "untaught",
  );
});

test("vault search query terms are limited for Firestore queries", () => {
  assert.deepEqual(
      vaultSearchQueryTerms("Ancient Wealth Architecture Digital Money Future"),
      ["architecture", "ancient", "digital", "future"],
  );
});

test("free users cannot open premium search results", () => {
  const freeUser = {
    role: "reader",
    accessLevel: "free",
    subscriptionStatus: "free",
  };

  assert.equal(canOpenPdfWithAccessLevel(freeUser, "free"), true);
  assert.equal(canOpenPdfWithAccessLevel(freeUser, "premium"), false);
});

test("premium users and admins can open premium search results", () => {
  assert.equal(
      canOpenPdfWithAccessLevel({
        role: "reader",
        accessLevel: "premium",
        subscriptionStatus: "active",
      }, "premium"),
      true,
  );

  assert.equal(
      canOpenPdfWithAccessLevel({
        role: "admin",
        accessLevel: "free",
        subscriptionStatus: "free",
      }, "premium"),
      true,
  );
});


class FakeVaultSearchFirestore {
  constructor() {
    this.collections = new Map();
  }

  collection(name) {
    if (!this.collections.has(name)) {
      this.collections.set(name, new Map());
    }

    const docs = this.collections.get(name);

    return {
      doc: (id) => ({
        get: async () => {
          const data = docs.get(id);
          return {
            exists: data !== undefined,
            data: () => data,
          };
        },
      }),

      where: (field, operator, value) =>
        this.query([...docs.entries()], [{field, operator, value}]),
    };
  }

  query(entries, filters) {
    return {
      where: (field, operator, value) =>
        this.query(entries, [...filters, {field, operator, value}]),
      limit: (count) => ({
        get: async () => {
          const matches = entries
              .filter(([, data]) => {
                return filters.every(({field, operator, value}) => {
                  const fieldValue = data && data[field];
                  if (operator === "array-contains") {
                    return Array.isArray(fieldValue) &&
                      fieldValue.includes(value);
                  }
                  if (operator === "==") {
                    return fieldValue === value;
                  }
                  throw new Error(`Unsupported operator: ${operator}`);
                });
              })
              .slice(0, count)
              .map(([id, data]) => ({
                id,
                data: () => data,
              }));

          return {docs: matches};
        },
      }),
    };
  }

  set(collection, id, data) {
    if (!this.collections.has(collection)) {
      this.collections.set(collection, new Map());
    }

    this.collections.get(collection).set(id, data);
  }
}

function fakeVaultSearchResponse() {
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

function fakeVaultSearchRequest({
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

test("secure vault search returns only free results to free users", async () => {
  const firestore = new FakeVaultSearchFirestore();

  firestore.set("users", "reader@example.com", {
    email: "reader@example.com",
    role: "reader",
    accessLevel: "free",
    subscriptionStatus: "free",
  });

  firestore.set("pdf_search_index", "free-result", {
    pdfTitle: "Free Money Guide",
    accessLevel: "free",
    pageNumber: 1,
    category: "Finance",
    text: "Money education for free readers.",
    keywords: ["money", "education"],
    titleKeywords: ["free", "money", "guide"],
    storagePath: "free/free-money-guide.pdf",
    pdfUrl: "https://example.test/free.pdf",
  });

  firestore.set("pdf_search_index", "premium-result", {
    pdfTitle: "Premium Secret Wealth Manual",
    accessLevel: "premium",
    pageNumber: 7,
    category: "Premium",
    text: "Premium money strategy reserved for subscribers.",
    keywords: ["money", "strategy"],
    titleKeywords: ["premium", "secret", "wealth"],
    storagePath: "premium/secret-wealth-manual.pdf",
  });

  const handler = createVaultSearchHandler({
    firestore,
    verifyAuthToken: async () => ({
      uid: "reader-1",
      email: "reader@example.com",
    }),
  });

  const response = fakeVaultSearchResponse();

  await handler(
      fakeVaultSearchRequest({
        body: {
          data: {
            query: "money",
          },
        },
      }),
      response,
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(
      response.body.results.map((result) => result.pdfTitle),
      ["Free Money Guide"],
  );
  assert.equal(response.body.results[0].accessLevel, "free");
  assert.equal(response.body.results[0].pdfUrl, "https://example.test/free.pdf");
});

test("free vault search filters access before applying result limits", async () => {
  const firestore = new FakeVaultSearchFirestore();

  firestore.set("users", "reader@example.com", {
    email: "reader@example.com",
    role: "reader",
    accessLevel: "free",
    subscriptionStatus: "free",
  });

  for (let i = 0; i < 40; i++) {
    firestore.set("pdf_search_index", `premium-money-${i}`, {
      pdfTitle: "Premium Money Manual",
      accessLevel: "premium",
      pageNumber: i + 1,
      category: "Premium",
      text: "Premium money strategy reserved for subscribers.",
      keywords: ["money", "strategy"],
      titleKeywords: ["premium", "money"],
      storagePath: `premium/money-${i}.pdf`,
    });
  }

  firestore.set("pdf_search_index", "free-money-page", {
    pdfTitle: "Free Partnership Proposal",
    accessLevel: "free",
    pageNumber: 7,
    category: "General",
    text: "This free page explains how money supports the partnership.",
    keywords: ["money", "partnership"],
    titleKeywords: ["free", "partnership", "proposal"],
    storagePath: "free/partnership.pdf",
    pdfUrl: "https://example.test/partnership.pdf",
  });

  const handler = createVaultSearchHandler({
    firestore,
    verifyAuthToken: async () => ({
      uid: "reader-1",
      email: "reader@example.com",
    }),
  });

  const response = fakeVaultSearchResponse();

  await handler(
      fakeVaultSearchRequest({
        body: {
          data: {
            query: "money",
          },
        },
      }),
      response,
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(
      response.body.results.map((result) => result.pdfTitle),
      ["Free Partnership Proposal"],
  );
});

test("free vault search falls back to indexed page text content", async () => {
  const firestore = new FakeVaultSearchFirestore();

  firestore.set("users", "reader@example.com", {
    email: "reader@example.com",
    role: "reader",
    accessLevel: "free",
    subscriptionStatus: "free",
  });

  firestore.set("pdf_search_index", "free-text-money-page", {
    pdfTitle: "Free Investor Memo",
    accessLevel: "free",
    pageNumber: 3,
    category: "General",
    text: "This excerpt starts before the searched word.",
    textLower: "this page discusses how money moves through the ecosystem.",
    keywords: ["investor", "ecosystem"],
    titleKeywords: ["free", "investor", "memo"],
    storagePath: "free/investor-memo.pdf",
    pdfUrl: "https://example.test/investor-memo.pdf",
  });

  const handler = createVaultSearchHandler({
    firestore,
    verifyAuthToken: async () => ({
      uid: "reader-1",
      email: "reader@example.com",
    }),
  });

  const response = fakeVaultSearchResponse();

  await handler(
      fakeVaultSearchRequest({
        body: {
          data: {
            query: "money",
          },
        },
      }),
      response,
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(
      response.body.results.map((result) => result.pdfTitle),
      ["Free Investor Memo"],
  );
});

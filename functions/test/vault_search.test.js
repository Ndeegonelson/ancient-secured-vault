const test = require("node:test");
const assert = require("node:assert/strict");
const {
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

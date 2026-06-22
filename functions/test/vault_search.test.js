const test = require("node:test");
const assert = require("node:assert/strict");
const {
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
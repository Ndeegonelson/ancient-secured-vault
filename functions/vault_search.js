function vaultSearchTerms(query) {
  const terms = cleanText(query)
      .toLowerCase()
      .replace(/[^a-z0-9 ]/g, " ")
      .split(/\s+/)
      .map((term) => term.trim())
      .filter((term) => term.length > 2);

  const uniqueTerms = [...new Set(terms)];
  uniqueTerms.sort((a, b) => {
    const lengthComparison = b.length - a.length;
    if (lengthComparison !== 0) return lengthComparison;

    return a.localeCompare(b);
  });

  return uniqueTerms;
}

function vaultPrimarySearchTerm(query) {
  const terms = vaultSearchTerms(query);
  if (terms.length > 0) return terms[0];

  const fallbackTerms = cleanText(query)
      .toLowerCase()
      .replace(/[^a-z0-9 ]/g, " ")
      .split(/\s+/)
      .map((term) => term.trim())
      .filter((term) => term.length > 0);

  return fallbackTerms[0] || "";
}

function vaultSearchQueryTerms(query, limit = 4) {
  if (!Number.isSafeInteger(limit) || limit <= 0) {
    throw new TypeError("Search term limit must be a positive integer.");
  }

  const terms = vaultSearchTerms(query).slice(0, limit);
  if (terms.length > 0) return terms;

  const fallbackTerm = vaultPrimarySearchTerm(query);
  return fallbackTerm ? [fallbackTerm] : [];
}

function cleanText(value) {
  return value == null ? "" : String(value).trim();
}

module.exports = {
  vaultPrimarySearchTerm,
  vaultSearchQueryTerms,
  vaultSearchTerms,
};

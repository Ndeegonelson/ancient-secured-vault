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

function canOpenPdfWithAccessLevel(userAccess, documentAccessLevel) {
  const level = cleanText(documentAccessLevel).toLowerCase();
  if (level !== "premium") return true;
  if (!userAccess || typeof userAccess !== "object") return false;

  const role = cleanText(userAccess.role).toLowerCase();
  const accessLevel = cleanText(userAccess.accessLevel).toLowerCase();
  const status = cleanText(userAccess.subscriptionStatus).toLowerCase();

  return role === "admin" ||
    accessLevel === "premium" ||
    status === "active" ||
    status === "trial";
}

function cleanText(value) {
  return value == null ? "" : String(value).trim();
}

module.exports = {
  canOpenPdfWithAccessLevel,
  vaultPrimarySearchTerm,
  vaultSearchQueryTerms,
  vaultSearchTerms,
};

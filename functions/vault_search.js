const MAX_QUERY_TERMS = 4;
const MAX_RESULTS_PER_TERM = 30;
const MAX_RETURNED_RESULTS = 80;

function createVaultSearchHandler({
  firestore,
  verifyAuthToken = defaultVerifyAuthToken,
} = {}) {
  if (!firestore) throw new TypeError("Firestore is required.");

  return async (request, response) => {
    try {
      applyCors(request, response);

      if (request.method === "OPTIONS") {
        response.status(204).send("");
        return;
      }

      requireMethod(request, "POST");

      const user = await requireFirebaseUser(request, verifyAuthToken);
      const userAccess = await loadUserAccess({firestore, user});
      const input = readRequestData(request);
      const query = cleanText(input.query);
      const searchTerms = vaultSearchQueryTerms(query);

      if (searchTerms.length === 0) {
        throw httpError(400, "Enter a searchable word.");
      }

      const results = await searchVaultIndex({
        firestore,
        query,
        searchTerms,
        userAccess,
      });

      response.json({
        query,
        searchTerms,
        results,
      });
    } catch (error) {
      sendHttpError(response, error);
    }
  };
}

async function searchVaultIndex({firestore, query, searchTerms, userAccess}) {
  const docsById = new Map();
  const collection = firestore.collection("pdf_search_index");

  for (const term of searchTerms) {
    const keywordSnapshot = await collection
        .where("keywords", "array-contains", term)
        .limit(MAX_RESULTS_PER_TERM)
        .get();

    for (const doc of keywordSnapshot.docs) {
      docsById.set(doc.id, doc);
    }

    const titleSnapshot = await collection
        .where("titleKeywords", "array-contains", term)
        .limit(MAX_RESULTS_PER_TERM)
        .get();

    for (const doc of titleSnapshot.docs) {
      docsById.set(doc.id, doc);
    }
  }

  const filtered = [...docsById.values()]
      .map((doc) => ({id: doc.id, data: doc.data() || {}}))
      .filter(({data}) => matchesQuery(data, query))
      .filter(({data}) => canOpenPdfWithAccessLevel(
          userAccess,
          cleanText(data.accessLevel) || "free",
      ));

  filtered.sort((left, right) => {
    const rightScore = vaultSearchMatchScore({
      query,
      title: cleanText(right.data.pdfTitle),
      text: cleanText(right.data.text),
      pageKeywords: Array.isArray(right.data.keywords)
        ? right.data.keywords
        : [],
      titleKeywords: Array.isArray(right.data.titleKeywords)
        ? right.data.titleKeywords
        : [],
    });

    const leftScore = vaultSearchMatchScore({
      query,
      title: cleanText(left.data.pdfTitle),
      text: cleanText(left.data.text),
      pageKeywords: Array.isArray(left.data.keywords)
        ? left.data.keywords
        : [],
      titleKeywords: Array.isArray(left.data.titleKeywords)
        ? left.data.titleKeywords
        : [],
    });

    const scoreComparison = rightScore - leftScore;
    if (scoreComparison !== 0) return scoreComparison;

    const titleComparison = cleanText(left.data.pdfTitle)
        .localeCompare(cleanText(right.data.pdfTitle));
    if (titleComparison !== 0) return titleComparison;

    return safeInteger(left.data.pageNumber) -
      safeInteger(right.data.pageNumber);
  });

  return filtered.slice(0, MAX_RETURNED_RESULTS).map(({id, data}) => {
    const accessLevel = cleanText(data.accessLevel) || "free";
    const text = cleanText(data.text);
    const snippetKeyword = vaultBestSnippetKeyword(text, query);
    const snippet = buildVaultSearchSnippet(
        text,
        snippetKeyword || vaultPrimarySearchTerm(query),
    );

    const result = {
      id,
      pdfTitle: cleanText(data.pdfTitle),
      pageNumber: safeInteger(data.pageNumber),
      category: cleanText(data.category) || "General",
      accessLevel,
      text: snippet,
      storagePath: cleanText(data.storagePath),
      readerMode: cleanText(data.readerMode),
      protectionMode: cleanText(data.protectionMode),
    };

    if (accessLevel === "free" && cleanText(data.pdfUrl)) {
      result.pdfUrl = cleanText(data.pdfUrl);
    }

    return result;
  });
}

async function loadUserAccess({firestore, user}) {
  if (user.uid) {
    const uidSnapshot = await firestore.collection("users").doc(user.uid).get();
    if (uidSnapshot.exists) return uidSnapshot.data() || {};
  }

  const emailSnapshot = await firestore
      .collection("users")
      .doc(user.email)
      .get();

  if (emailSnapshot.exists) return emailSnapshot.data() || {};

  return {
    email: user.email,
    role: "reader",
    accessLevel: "free",
    subscriptionStatus: "free",
  };
}

function matchesQuery(data, query) {
  const titleKeywords = data.titleKeywords;

  const hasIndexedTitleMatch = Array.isArray(titleKeywords) &&
    vaultIndexedTermsMatchQuery(titleKeywords, query);

  const hasLegacyTitleMatch = titleKeywords == null &&
    vaultTextMatchesAnySearchTerm(cleanText(data.pdfTitle), query);

  const hasPageMatch = Array.isArray(data.keywords) &&
    vaultIndexedTermsMatchQuery(data.keywords, query);

  return hasIndexedTitleMatch || hasLegacyTitleMatch || hasPageMatch;
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

function vaultSearchQueryTerms(query, limit = MAX_QUERY_TERMS) {
  if (!Number.isSafeInteger(limit) || limit <= 0) {
    throw new TypeError("Search term limit must be a positive integer.");
  }

  const terms = vaultSearchTerms(query).slice(0, limit);
  if (terms.length > 0) return terms;

  const fallbackTerm = vaultPrimarySearchTerm(query);
  return fallbackTerm ? [fallbackTerm] : [];
}

function vaultTextMatchesAnySearchTerm(text, query) {
  const textTerms = new Set(vaultSearchTerms(text));
  if (textTerms.size === 0) return false;

  for (const term of vaultSearchTerms(query)) {
    if (textTerms.has(term)) return true;
  }

  const fallbackTerm = vaultPrimarySearchTerm(query);
  return fallbackTerm !== "" && textTerms.has(fallbackTerm);
}

function vaultIndexedTermsMatchQuery(values, query) {
  const indexedTerms = new Set(values.map((value) => String(value)));

  if (indexedTerms.size === 0) return false;

  for (const term of vaultSearchTerms(query)) {
    if (indexedTerms.has(term)) return true;
  }

  const fallbackTerm = vaultPrimarySearchTerm(query);
  return fallbackTerm !== "" && indexedTerms.has(fallbackTerm);
}

function vaultBestSnippetKeyword(text, query) {
  const clean = cleanText(text).toLowerCase().replace(/\s+/g, " ");

  for (const term of vaultSearchTerms(query)) {
    if (clean.includes(term)) return term;
  }

  const fallbackTerm = vaultPrimarySearchTerm(query);
  return clean.includes(fallbackTerm) ? fallbackTerm : "";
}

function vaultSearchMatchScore({
  query,
  title = "",
  text = "",
  pageKeywords = [],
  titleKeywords = [],
}) {
  const terms = vaultSearchTerms(query);
  if (terms.length === 0) return 0;

  const normalizedTitle = cleanText(title).toLowerCase();
  const normalizedText = cleanText(text).toLowerCase();
  const pageTermSet = new Set(pageKeywords.map((value) => String(value)));
  const titleTermSet = new Set(titleKeywords.map((value) => String(value)));
  const phrase = cleanText(query).toLowerCase().replace(/\s+/g, " ").trim();
  let score = 0;

  if (phrase && normalizedTitle.includes(phrase)) score += 18;
  if (phrase && normalizedText.includes(phrase)) score += 8;

  for (const term of terms) {
    if (titleTermSet.has(term)) score += 12;
    if (pageTermSet.has(term)) score += 7;
    if (normalizedTitle.includes(term)) score += 5;
    if (normalizedText.includes(term)) score += 2;
  }

  return score;
}

function buildVaultSearchSnippet(text, keyword, contextCharacters = 70) {
  const clean = cleanText(text).replace(/\s+/g, " ").trim();
  const cleanKeyword = cleanText(keyword);

  if (!clean) return "";
  if (!cleanKeyword) return trimSnippet(clean, 0, contextCharacters * 2);

  const matchIndex = clean.toLowerCase().indexOf(cleanKeyword.toLowerCase());
  if (matchIndex < 0) return trimSnippet(clean, 0, contextCharacters * 2);

  const start = clamp(matchIndex - contextCharacters, 0, clean.length);
  const end = clamp(
      matchIndex + cleanKeyword.length + contextCharacters,
      start,
      clean.length,
  );

  return trimSnippet(clean, start, end);
}

function trimSnippet(text, start, end) {
  const safeStart = clamp(start, 0, text.length);
  const safeEnd = clamp(end, safeStart, text.length);
  const prefix = safeStart > 0 ? "... " : "";
  const suffix = safeEnd < text.length ? " ..." : "";

  return `${prefix}${text.substring(safeStart, safeEnd).trim()}${suffix}`;
}

async function requireFirebaseUser(request, verifyAuthToken) {
  const authorization = request.get("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);

  if (!match) {
    throw httpError(401, "Sign in before searching the vault.");
  }

  const decoded = await verifyAuthToken(match[1]);
  const email = cleanEmail(decoded && decoded.email);

  if (!email) {
    throw httpError(403, "A verified email is required for vault search.");
  }

  return {
    uid: cleanText(decoded.uid),
    email,
  };
}

function defaultVerifyAuthToken(token) {
  return require("firebase-admin/auth").getAuth().verifyIdToken(token);
}

function readRequestData(request) {
  const body = request.body && request.body.data
    ? request.body.data
    : request.body;

  if (!body || typeof body !== "object") return {};

  return {
    query: cleanText(body.query),
  };
}

function requireMethod(request, method) {
  if (request.method !== method) {
    throw httpError(405, `Vault search requires ${method}.`);
  }
}

function applyCors(request, response) {
  const origin = request.get("origin") || "*";
  response.set("Access-Control-Allow-Origin", origin);
  response.set("Vary", "Origin");
  response.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
}

function sendHttpError(response, error) {
  response.status(error && error.status ? error.status : 500).json({
    error: {
      message: error && error.message
        ? error.message
        : "Vault search is temporarily unavailable.",
    },
  });
}

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function cleanEmail(value) {
  const email = cleanText(value).toLowerCase();
  return email.includes("@") ? email : "";
}

function cleanText(value) {
  return value == null ? "" : String(value).trim();
}

function safeInteger(value) {
  if (Number.isSafeInteger(value)) return value;

  const parsed = Number.parseInt(String(value), 10);
  return Number.isSafeInteger(parsed) ? parsed : 0;
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

module.exports = {
  buildVaultSearchSnippet,
  canOpenPdfWithAccessLevel,
  createVaultSearchHandler,
  vaultIndexedTermsMatchQuery,
  vaultPrimarySearchTerm,
  vaultSearchMatchScore,
  vaultSearchQueryTerms,
  vaultSearchTerms,
};

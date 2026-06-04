const {HttpsError} = require("firebase-functions/v2/https");

const DEFAULT_CATALOG_TTL_MILLISECONDS = 5 * 60 * 1000;
const MAX_PROVIDER_VOICES = 100;

function createNarrationProviderRegistry({
  providers = [],
  catalogTtlMilliseconds = DEFAULT_CATALOG_TTL_MILLISECONDS,
  now = () => Date.now(),
} = {}) {
  const approvedProviders = validateProviders(providers);
  const safeTtl = requirePositiveInteger(
      catalogTtlMilliseconds,
      "catalogTtlMilliseconds",
  );
  requireFunction(now, "now");

  let cachedCatalog;
  let catalogExpiresAt = 0;
  let refreshPromise;

  async function loadRoutes() {
    const currentTime = requireCurrentTime(now());
    if (cachedCatalog && currentTime < catalogExpiresAt) {
      return cachedCatalog;
    }
    if (refreshPromise) return refreshPromise;

    refreshPromise = buildCatalog(approvedProviders)
        .then((catalog) => {
          cachedCatalog = catalog;
          catalogExpiresAt = requireCurrentTime(now()) + safeTtl;
          return catalog;
        })
        .finally(() => {
          refreshPromise = undefined;
        });

    return refreshPromise;
  }

  async function resolveVoice(publicVoiceId) {
    const safeVoiceId = requireVoiceId(publicVoiceId);
    const catalog = await loadRoutes();
    const route = catalog.routes.get(safeVoiceId);
    if (!route) {
      throw new HttpsError(
          "failed-precondition",
          "The selected cloud narrator is not currently available.",
      );
    }
    return route;
  }

  return {
    async loadCatalog() {
      const catalog = await loadRoutes();
      return catalog.publicVoices;
    },

    async authorizeVoice(publicVoiceId) {
      await resolveVoice(publicVoiceId);
    },

    async synthesize(input) {
      const route = await resolveVoice(input && input.voiceId);
      return route.provider.synthesize({
        text: input.text,
        rate: input.rate,
        startCharacter: input.startCharacter,
        voice: route.providerVoice,
      });
    },

    clearCache() {
      cachedCatalog = undefined;
      catalogExpiresAt = 0;
    },
  };
}

async function buildCatalog(providers) {
  const routes = new Map();
  const publicVoices = [];

  for (const provider of providers) {
    try {
      const voices = await provider.loadVoices();
      const normalizedVoices = validateProviderVoices(provider.key, voices);

      for (const voice of normalizedVoices) {
        routes.set(voice.publicVoice.id, {
          provider,
          providerVoice: voice.providerVoice,
        });
        publicVoices.push(voice.publicVoice);
      }
    } catch (_) {
      // A provider failure must not remove healthy providers from the catalog.
    }
  }

  return Object.freeze({
    publicVoices: Object.freeze(publicVoices),
    routes,
  });
}

function validateProviders(value) {
  if (!Array.isArray(value)) {
    throw new TypeError("providers must be an array.");
  }

  const providerKeys = new Set();
  return Object.freeze(value.map((provider) => {
    if (!isPlainObject(provider)) {
      throw new TypeError("Cloud narration provider is invalid.");
    }

    const key = requireProviderKey(provider.key);
    if (providerKeys.has(key)) {
      throw new TypeError(`Duplicate cloud narration provider key: ${key}.`);
    }
    providerKeys.add(key);
    requireFunction(provider.loadVoices, `${key}.loadVoices`);
    requireFunction(provider.synthesize, `${key}.synthesize`);
    return Object.freeze({
      key,
      loadVoices: (...args) => provider.loadVoices(...args),
      synthesize: (...args) => provider.synthesize(...args),
    });
  }));
}

function validateProviderVoices(providerKey, value) {
  if (!Array.isArray(value) || value.length > MAX_PROVIDER_VOICES) {
    throw new TypeError("Provider voice catalog is invalid.");
  }

  const voiceIds = new Set();
  return value.map((voice) => {
    if (!isPlainObject(voice)) {
      throw new TypeError("Provider voice is invalid.");
    }

    const providerVoiceId = requireProviderVoiceId(voice.id);
    if (voiceIds.has(providerVoiceId)) {
      throw new TypeError("Provider voice IDs must be unique.");
    }
    voiceIds.add(providerVoiceId);

    const providerVoice = Object.freeze({
      id: providerVoiceId,
      name: requireString(voice.name, "voice name", 120),
      locale: requireString(voice.locale, "voice locale", 35),
      ...optionalVoiceMetadata(voice),
      isCustom: voice.isCustom === true,
    });

    return Object.freeze({
      providerVoice,
      publicVoice: Object.freeze({
        ...providerVoice,
        id: `${providerKey}:${providerVoiceId}`,
      }),
    });
  });
}

function optionalVoiceMetadata(voice) {
  const metadata = {};
  copyOptionalString(voice, metadata, "gender", 40);
  copyOptionalString(voice, metadata, "accent", 80);
  copyOptionalString(voice, metadata, "style", 80);
  return metadata;
}

function copyOptionalString(source, target, field, maximumLength) {
  if (source[field] === undefined) return;
  target[field] = requireString(source[field], field, maximumLength);
}

function requireProviderKey(value) {
  const key = requireString(value, "provider key", 50);
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(key)) {
    throw new TypeError("Cloud narration provider key is invalid.");
  }
  return key;
}

function requireProviderVoiceId(value) {
  const id = requireString(value, "provider voice id", 200);
  if (id.includes(":")) {
    throw new TypeError("Provider voice ID cannot contain a colon.");
  }
  return id;
}

function requireVoiceId(value) {
  if (typeof value !== "string" || value.trim() === "") {
    throw new HttpsError(
        "invalid-argument",
        "A valid cloud narrator is required.",
    );
  }
  return value.trim();
}

function requireString(value, fieldName, maximumLength) {
  if (typeof value !== "string") {
    throw new TypeError(`${fieldName} is invalid.`);
  }
  const normalized = value.trim();
  if (normalized === "" || normalized.length > maximumLength) {
    throw new TypeError(`${fieldName} is invalid.`);
  }
  return normalized;
}

function requirePositiveInteger(value, fieldName) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new TypeError(`${fieldName} must be a positive whole number.`);
  }
  return value;
}

function requireCurrentTime(value) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new TypeError("now must return a positive whole number.");
  }
  return value;
}

function requireFunction(value, name) {
  if (typeof value !== "function") {
    throw new TypeError(`${name} must be a function.`);
  }
}

function isPlainObject(value) {
  return value !== null &&
    typeof value === "object" &&
    !Array.isArray(value);
}

module.exports = {
  DEFAULT_CATALOG_TTL_MILLISECONDS,
  createNarrationProviderRegistry,
};

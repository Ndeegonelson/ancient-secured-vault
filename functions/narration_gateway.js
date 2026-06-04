const {HttpsError} = require("firebase-functions/v2/https");

const MAX_CATALOG_VOICES = 100;
const MAX_SYNTHESIS_CHARACTERS = 2400;
const MAX_AUDIO_BYTES = 8 * 1024 * 1024;
const MAX_AUDIO_DURATION_MILLISECONDS = 10 * 60 * 1000;
const MIN_NARRATION_RATE = 0.5;
const MAX_NARRATION_RATE = 2;

function createNarrationCatalogHandler({loadUserAccess, loadCatalog}) {
  requireDependency(loadUserAccess, "loadUserAccess");
  requireDependency(loadCatalog, "loadCatalog");

  return async (request) => {
    await requireCloudNarrationAccess(request, loadUserAccess);

    const catalog = await callProviderSafely(
        loadCatalog,
        "Cloud narration voices are temporarily unavailable.",
    );
    const voices = validateCatalog(catalog);
    return {
      status: voices.length === 0 ? "notConfigured" : "ready",
      voices,
    };
  };
}

function createNarrationSynthesisHandler({
  loadUserAccess,
  consumeUsage,
  synthesize,
}) {
  requireDependency(loadUserAccess, "loadUserAccess");
  requireDependency(consumeUsage, "consumeUsage");
  requireDependency(synthesize, "synthesize");

  return async (request) => {
    const access = await requireCloudNarrationAccess(request, loadUserAccess);
    const input = validateSynthesisInput(request.data);
    await consumeUsageSafely(() => consumeUsage({
      uid: request.auth.uid,
      access,
      characterCount: input.text.length,
    }));

    const result = await callProviderSafely(
        () => synthesize(input),
        "Cloud narration audio is temporarily unavailable.",
    );
    return validateSynthesisResult(result, input);
  };
}

async function requireCloudNarrationAccess(request, loadUserAccess) {
  const auth = request && request.auth;
  if (!auth || typeof auth.uid !== "string" || auth.uid.trim() === "") {
    throw new HttpsError(
        "unauthenticated",
        "Sign in before using cloud narration.",
    );
  }

  let access;
  try {
    access = await loadUserAccess({
      uid: auth.uid,
      email: normalizeOptionalString(auth.token && auth.token.email),
    });
  } catch (_) {
    throw new HttpsError(
        "unavailable",
        "Cloud narration access could not be verified.",
    );
  }

  if (!hasCloudNarrationAccess(access)) {
    throw new HttpsError(
        "permission-denied",
        "Premium narration is required for cloud and customized voices.",
    );
  }

  return access;
}

function hasCloudNarrationAccess(access) {
  if (!isPlainObject(access)) return false;

  return access.role === "admin" || access.subscriptionStatus === "active";
}

function validateCatalog(value) {
  if (!Array.isArray(value)) {
    throw invalidCatalogError();
  }
  if (value.length > MAX_CATALOG_VOICES) {
    throw new HttpsError(
        "resource-exhausted",
        "The cloud narration voice catalog is too large.",
    );
  }

  const voiceIds = new Set();
  return value.map((voice) => {
    if (!isPlainObject(voice)) {
      throw invalidCatalogError();
    }

    const normalized = {
      id: requireString(voice.id, "voice id", 300, invalidCatalogError),
      name: requireString(voice.name, "voice name", 120, invalidCatalogError),
      locale: requireString(
          voice.locale,
          "voice locale",
          35,
          invalidCatalogError,
      ),
    };

    if (voiceIds.has(normalized.id)) {
      throw invalidCatalogError();
    }
    voiceIds.add(normalized.id);

    copyOptionalCatalogField(voice, normalized, "gender", 40);
    copyOptionalCatalogField(voice, normalized, "accent", 80);
    copyOptionalCatalogField(voice, normalized, "style", 80);
    normalized.isCustom = voice.isCustom === true;
    return normalized;
  });
}

function validateSynthesisInput(value) {
  if (!isPlainObject(value)) {
    throw new HttpsError(
        "invalid-argument",
        "Cloud narration request data is required.",
    );
  }

  const text = requireNarrationText(value.text);
  const voiceId = requireString(value.voiceId, "voice id", 300);
  const rate = value.rate;
  const startCharacter = value.startCharacter === undefined ?
    0 :
    value.startCharacter;

  if (typeof rate !== "number" ||
      !Number.isFinite(rate) ||
      rate < MIN_NARRATION_RATE ||
      rate > MAX_NARRATION_RATE) {
    throw new HttpsError(
        "invalid-argument",
        `Narration speed must be between ${MIN_NARRATION_RATE} and ` +
          `${MAX_NARRATION_RATE}.`,
    );
  }
  if (!Number.isSafeInteger(startCharacter) ||
      startCharacter < 0 ||
      startCharacter > Number.MAX_SAFE_INTEGER - text.length) {
    throw new HttpsError(
        "invalid-argument",
        "Narration start position must be a positive whole number.",
    );
  }

  return Object.freeze({text, voiceId, rate, startCharacter});
}

function validateSynthesisResult(value, request) {
  if (!isPlainObject(value)) {
    throw invalidSynthesisResultError();
  }

  const audioBase64 = requireString(
      value.audioBase64,
      "audio data",
      Math.ceil(MAX_AUDIO_BYTES * 4 / 3) + 4,
      invalidSynthesisResultError,
  );
  if (!isValidBase64(audioBase64)) {
    throw invalidSynthesisResultError();
  }

  const audioBytes = Buffer.from(audioBase64, "base64");
  if (audioBytes.length === 0 || audioBytes.length > MAX_AUDIO_BYTES) {
    throw invalidSynthesisResultError();
  }

  const contentType = requireString(
      value.contentType,
      "audio content type",
      100,
      invalidSynthesisResultError,
  ).toLowerCase();
  const expectedEndCharacter = request.startCharacter + request.text.length;
  if (!contentType.startsWith("audio/") ||
      value.startCharacter !== request.startCharacter ||
      value.endCharacter !== expectedEndCharacter) {
    throw invalidSynthesisResultError();
  }

  const result = {
    audioBase64,
    contentType,
    startCharacter: request.startCharacter,
    endCharacter: expectedEndCharacter,
    timingCues: validateTimingCues(
        value.timingCues,
        request.startCharacter,
        expectedEndCharacter,
    ),
  };

  if (value.durationMilliseconds !== undefined) {
    if (!Number.isSafeInteger(value.durationMilliseconds) ||
        value.durationMilliseconds <= 0 ||
        value.durationMilliseconds > MAX_AUDIO_DURATION_MILLISECONDS) {
      throw invalidSynthesisResultError();
    }
    result.durationMilliseconds = value.durationMilliseconds;
  }

  return result;
}

function validateTimingCues(value, startCharacter, endCharacter) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > MAX_SYNTHESIS_CHARACTERS) {
    throw invalidSynthesisResultError();
  }

  let previousOffset = -1;
  return value.map((cue) => {
    if (!isPlainObject(cue) ||
        !Number.isSafeInteger(cue.startCharacter) ||
        !Number.isSafeInteger(cue.endCharacter) ||
        !Number.isSafeInteger(cue.audioOffsetMilliseconds) ||
        cue.startCharacter < startCharacter ||
        cue.endCharacter <= cue.startCharacter ||
        cue.endCharacter > endCharacter ||
        cue.audioOffsetMilliseconds < 0 ||
        cue.audioOffsetMilliseconds < previousOffset) {
      throw invalidSynthesisResultError();
    }

    previousOffset = cue.audioOffsetMilliseconds;
    return {
      startCharacter: cue.startCharacter,
      endCharacter: cue.endCharacter,
      audioOffsetMilliseconds: cue.audioOffsetMilliseconds,
    };
  });
}

function copyOptionalCatalogField(source, target, field, maximumLength) {
  const normalized = normalizeOptionalString(source[field]);
  if (normalized === undefined) return;
  if (normalized.length > maximumLength) throw invalidCatalogError();
  target[field] = normalized;
}

function requireString(
    value,
    fieldName,
    maximumLength,
    errorFactory = invalidArgumentError,
) {
  if (typeof value !== "string") throw errorFactory(fieldName);

  const normalized = value.trim();
  if (normalized === "" || normalized.length > maximumLength) {
    throw errorFactory(fieldName);
  }
  return normalized;
}

function requireNarrationText(value) {
  if (typeof value !== "string" ||
      value.trim() === "" ||
      value.length > MAX_SYNTHESIS_CHARACTERS) {
    throw invalidArgumentError("narration text");
  }

  return value;
}

function normalizeOptionalString(value) {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim();
  return normalized === "" ? undefined : normalized;
}

function isValidBase64(value) {
  if (value.length % 4 !== 0 ||
      !/^[A-Za-z0-9+/]*={0,2}$/.test(value)) {
    return false;
  }

  return Buffer.from(value, "base64").toString("base64") === value;
}

function isPlainObject(value) {
  return value !== null &&
    typeof value === "object" &&
    !Array.isArray(value);
}

function requireDependency(value, name) {
  if (typeof value !== "function") {
    throw new TypeError(`${name} must be a function.`);
  }
}

function invalidArgumentError(fieldName) {
  return new HttpsError(
      "invalid-argument",
      `A valid ${fieldName} is required.`,
  );
}

function invalidCatalogError() {
  return new HttpsError(
      "internal",
      "The cloud narration provider returned an invalid voice catalog.",
  );
}

function invalidSynthesisResultError() {
  return new HttpsError(
      "internal",
      "The cloud narration provider returned invalid protected audio.",
  );
}

async function callProviderSafely(
    operation,
    fallbackMessage,
) {
  try {
    return await operation();
  } catch (_) {
    throw new HttpsError("unavailable", fallbackMessage);
  }
}

async function consumeUsageSafely(operation) {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpsError &&
        error.code === "resource-exhausted") {
      throw error;
    }
    throw new HttpsError(
        "unavailable",
        "Cloud narration allowance could not be verified.",
    );
  }
}

module.exports = {
  MAX_AUDIO_BYTES,
  MAX_AUDIO_DURATION_MILLISECONDS,
  MAX_SYNTHESIS_CHARACTERS,
  createNarrationCatalogHandler,
  createNarrationSynthesisHandler,
  hasCloudNarrationAccess,
  validateCatalog,
  validateSynthesisInput,
  validateSynthesisResult,
};

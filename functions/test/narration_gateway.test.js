const test = require("node:test");
const assert = require("node:assert/strict");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  MAX_AUDIO_BYTES,
  MAX_AUDIO_DURATION_MILLISECONDS,
  MAX_SYNTHESIS_CHARACTERS,
  createNarrationCatalogHandler,
  createNarrationSynthesisHandler,
  validateSynthesisResult,
} = require("../narration_gateway");

const premiumAccess = {
  role: "reader",
  subscriptionStatus: "active",
};

function authenticatedRequest(data = {}) {
  return {
    auth: {
      uid: "reader-123",
      token: {email: "reader@example.com"},
    },
    data,
  };
}

function expectHttpsCode(code) {
  return (error) => {
    assert.equal(error.code, code);
    return true;
  };
}

test("catalog requires an authenticated user", async () => {
  let accessReads = 0;
  const handler = createNarrationCatalogHandler({
    loadUserAccess: async () => {
      accessReads++;
      return premiumAccess;
    },
    loadCatalog: async () => [],
  });

  await assert.rejects(handler({data: {}}), expectHttpsCode("unauthenticated"));
  assert.equal(accessReads, 0);
});

test("catalog rejects free users before loading paid voices", async () => {
  let catalogReads = 0;
  const handler = createNarrationCatalogHandler({
    loadUserAccess: async () => ({
      role: "reader",
      subscriptionStatus: "inactive",
    }),
    loadCatalog: async () => {
      catalogReads++;
      return [];
    },
  });

  await assert.rejects(
      handler(authenticatedRequest()),
      expectHttpsCode("permission-denied"),
  );
  assert.equal(catalogReads, 0);
});

test("premium catalog returns only validated narrator metadata", async () => {
  const handler = createNarrationCatalogHandler({
    loadUserAccess: async () => premiumAccess,
    loadCatalog: async () => [{
      id: "provider-voice-1",
      name: "Ama",
      locale: "en-GH",
      gender: "Female",
      accent: "Ghanaian",
      style: "Educational",
      isCustom: true,
      secretProviderField: "must not reach Flutter",
    }],
  });

  const result = await handler(authenticatedRequest());

  assert.deepEqual(result, {
    status: "ready",
    voices: [{
      id: "provider-voice-1",
      name: "Ama",
      locale: "en-GH",
      gender: "Female",
      accent: "Ghanaian",
      style: "Educational",
      isCustom: true,
    }],
  });
});

test("admins can access cloud narration without an active subscription", async () => {
  const handler = createNarrationCatalogHandler({
    loadUserAccess: async () => ({
      role: "admin",
      subscriptionStatus: "inactive",
    }),
    loadCatalog: async () => [],
  });

  const result = await handler(authenticatedRequest());

  assert.deepEqual(result, {status: "notConfigured", voices: []});
});

test("synthesis rejects oversized text before calling a paid provider", async () => {
  let synthesisCalls = 0;
  const handler = createNarrationSynthesisHandler({
    loadUserAccess: async () => premiumAccess,
    synthesize: async () => {
      synthesisCalls++;
      return {};
    },
  });

  await assert.rejects(
      handler(authenticatedRequest({
        text: "x".repeat(MAX_SYNTHESIS_CHARACTERS + 1),
        voiceId: "provider-voice-1",
        rate: 1,
      })),
      expectHttpsCode("invalid-argument"),
  );
  assert.equal(synthesisCalls, 0);
});

test("valid synthesis request returns bounded protected audio", async () => {
  let receivedInput;
  const audioBase64 = Buffer.from([1, 2, 3]).toString("base64");
  const handler = createNarrationSynthesisHandler({
    loadUserAccess: async () => premiumAccess,
    synthesize: async (input) => {
      receivedInput = input;
      return {
        audioBase64,
        contentType: "audio/mpeg",
        startCharacter: input.startCharacter,
        endCharacter: input.startCharacter + input.text.length,
        durationMilliseconds: 800,
        timingCues: [{
          startCharacter: input.startCharacter,
          endCharacter: input.startCharacter + input.text.length,
          audioOffsetMilliseconds: 0,
        }],
        secretProviderField: "must not reach Flutter",
      };
    },
  });

  const result = await handler(authenticatedRequest({
    text: "Bonjour.",
    voiceId: "provider-voice-1",
    rate: 0.8,
    startCharacter: 12,
  }));

  assert.deepEqual(receivedInput, {
    text: "Bonjour.",
    voiceId: "provider-voice-1",
    rate: 0.8,
    startCharacter: 12,
  });
  assert.deepEqual(result, {
    audioBase64,
    contentType: "audio/mpeg",
    startCharacter: 12,
    endCharacter: 20,
    durationMilliseconds: 800,
    timingCues: [{
      startCharacter: 12,
      endCharacter: 20,
      audioOffsetMilliseconds: 0,
    }],
  });
});

test("synthesis preserves text spacing used by document highlighting", async () => {
  let receivedInput;
  const handler = createNarrationSynthesisHandler({
    loadUserAccess: async () => premiumAccess,
    synthesize: async (input) => {
      receivedInput = input;
      return {
        audioBase64: Buffer.from([1]).toString("base64"),
        contentType: "audio/mpeg",
        startCharacter: input.startCharacter,
        endCharacter: input.startCharacter + input.text.length,
      };
    },
  });

  await handler(authenticatedRequest({
    text: "  Original PDF text. ",
    voiceId: "provider-voice-1",
    rate: 1,
    startCharacter: 50,
  }));

  assert.equal(receivedInput.text, "  Original PDF text. ");
});

test("invalid provider audio is rejected at the secure boundary", () => {
  const request = {
    text: "Protected narration.",
    voiceId: "provider-voice-1",
    rate: 1,
    startCharacter: 0,
  };

  assert.throws(
      () => validateSynthesisResult({
        audioBase64: Buffer.alloc(MAX_AUDIO_BYTES + 1).toString("base64"),
        contentType: "audio/mpeg",
        startCharacter: 0,
        endCharacter: request.text.length,
      }, request),
      expectHttpsCode("internal"),
  );
});

test("invalid provider duration is rejected at the secure boundary", () => {
  const request = {
    text: "Protected narration.",
    voiceId: "provider-voice-1",
    rate: 1,
    startCharacter: 0,
  };

  assert.throws(
      () => validateSynthesisResult({
        audioBase64: Buffer.from([1]).toString("base64"),
        contentType: "audio/mpeg",
        startCharacter: 0,
        endCharacter: request.text.length,
        durationMilliseconds: MAX_AUDIO_DURATION_MILLISECONDS + 1,
      }, request),
      expectHttpsCode("internal"),
  );
});

test("provider failures are sanitized before reaching Flutter", async () => {
  const handler = createNarrationSynthesisHandler({
    loadUserAccess: async () => premiumAccess,
    synthesize: async () => {
      throw new Error("private provider credential detail");
    },
  });

  await assert.rejects(
      handler(authenticatedRequest({
        text: "Protected narration.",
        voiceId: "provider-voice-1",
        rate: 1,
      })),
      (error) => {
        assert.equal(error.code, "unavailable");
        assert.doesNotMatch(error.message, /credential/);
        return true;
      },
  );
});

test("provider Firebase errors are also sanitized before reaching Flutter", async () => {
  const handler = createNarrationSynthesisHandler({
    loadUserAccess: async () => premiumAccess,
    synthesize: async () => {
      throw new HttpsError(
          "failed-precondition",
          "private provider configuration detail",
      );
    },
  });

  await assert.rejects(
      handler(authenticatedRequest({
        text: "Protected narration.",
        voiceId: "provider-voice-1",
        rate: 1,
      })),
      (error) => {
        assert.equal(error.code, "unavailable");
        assert.doesNotMatch(error.message, /configuration detail/);
        return true;
      },
  );
});

test("server access lookup failures do not reveal internal details", async () => {
  const handler = createNarrationCatalogHandler({
    loadUserAccess: async () => {
      throw new Error("private database detail");
    },
    loadCatalog: async () => [],
  });

  await assert.rejects(
      handler(authenticatedRequest()),
      (error) => {
        assert.equal(error.code, "unavailable");
        assert.doesNotMatch(error.message, /private database detail/);
        return true;
      },
  );
});

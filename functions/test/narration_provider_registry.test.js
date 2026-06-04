const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createNarrationProviderRegistry,
} = require("../narration_provider_registry");

function createProvider({
  key,
  voices = [],
  loadError,
  synthesizeResult,
}) {
  return {
    key,
    loadCount: 0,
    synthesisRequests: [],
    async loadVoices() {
      this.loadCount++;
      if (loadError) throw loadError;
      return voices;
    },
    async synthesize(request) {
      this.synthesisRequests.push(request);
      return synthesizeResult || {provider: key};
    },
  };
}

function expectHttpsCode(code) {
  return (error) => {
    assert.equal(error.code, code);
    return true;
  };
}

test("empty registry safely exposes no paid narrators", async () => {
  const registry = createNarrationProviderRegistry();

  assert.deepEqual(await registry.loadCatalog(), []);
  await assert.rejects(
      registry.authorizeVoice("unknown:voice"),
      expectHttpsCode("failed-precondition"),
  );
});

test("catalog assigns server-owned provider-prefixed voice IDs", async () => {
  const provider = createProvider({
    key: "future-african-provider",
    voices: [{
      id: "ama-educator",
      name: "Ama",
      locale: "en-GH",
      accent: "Ghanaian",
      gender: "Female",
      style: "Educational",
      isCustom: true,
      privateProviderSetting: "must not leave the backend",
    }],
  });
  const registry = createNarrationProviderRegistry({providers: [provider]});

  const catalog = await registry.loadCatalog();

  assert.deepEqual(catalog, [{
    id: "future-african-provider:ama-educator",
    name: "Ama",
    locale: "en-GH",
    accent: "Ghanaian",
    gender: "Female",
    style: "Educational",
    isCustom: true,
  }]);
});

test("synthesis routes only approved voice metadata to its owner", async () => {
  const provider = createProvider({
    key: "future-provider",
    voices: [{
      id: "approved-voice",
      name: "Approved Narrator",
      locale: "fr-GH",
    }],
  });
  const registry = createNarrationProviderRegistry({providers: [provider]});
  const input = {
    text: "Bonjour.",
    voiceId: "future-provider:approved-voice",
    rate: 0.8,
    startCharacter: 20,
  };

  const result = await registry.synthesize(input);

  assert.deepEqual(result, {provider: "future-provider"});
  assert.deepEqual(provider.synthesisRequests, [{
    text: "Bonjour.",
    rate: 0.8,
    startCharacter: 20,
    voice: {
      id: "approved-voice",
      name: "Approved Narrator",
      locale: "fr-GH",
      isCustom: false,
    },
  }]);
});

test("arbitrary or removed narrator IDs never reach a provider", async () => {
  const provider = createProvider({
    key: "future-provider",
    voices: [{
      id: "approved-voice",
      name: "Approved Narrator",
      locale: "en-GH",
    }],
  });
  const registry = createNarrationProviderRegistry({providers: [provider]});

  await assert.rejects(
      registry.synthesize({
        text: "Protected narration.",
        voiceId: "future-provider:unapproved-voice",
        rate: 1,
        startCharacter: 0,
      }),
      expectHttpsCode("failed-precondition"),
  );
  assert.equal(provider.synthesisRequests.length, 0);
});

test("one failing provider does not remove healthy provider voices", async () => {
  const failingProvider = createProvider({
    key: "failing-provider",
    loadError: new Error("private provider error"),
  });
  const healthyProvider = createProvider({
    key: "healthy-provider",
    voices: [{
      id: "healthy-voice",
      name: "Healthy Narrator",
      locale: "en-GH",
    }],
  });
  const registry = createNarrationProviderRegistry({
    providers: [failingProvider, healthyProvider],
  });

  const catalog = await registry.loadCatalog();

  assert.deepEqual(catalog.map((voice) => voice.id), [
    "healthy-provider:healthy-voice",
  ]);
});

test("catalog cache prevents repeated provider catalog charges", async () => {
  let currentTime = 1000;
  const provider = createProvider({
    key: "future-provider",
    voices: [{
      id: "voice",
      name: "Narrator",
      locale: "en-GH",
    }],
  });
  const registry = createNarrationProviderRegistry({
    providers: [provider],
    catalogTtlMilliseconds: 100,
    now: () => currentTime,
  });

  await registry.loadCatalog();
  await registry.authorizeVoice("future-provider:voice");
  assert.equal(provider.loadCount, 1);

  currentTime = 1100;
  await registry.loadCatalog();
  assert.equal(provider.loadCount, 2);
});

test("simultaneous catalog requests share one provider refresh", async () => {
  let releaseCatalog;
  const provider = createProvider({
    key: "future-provider",
    voices: [{
      id: "voice",
      name: "Narrator",
      locale: "en-GH",
    }],
  });
  const originalLoadVoices = provider.loadVoices.bind(provider);
  provider.loadVoices = async () => {
    await new Promise((resolve) => {
      releaseCatalog = resolve;
    });
    return originalLoadVoices();
  };
  const registry = createNarrationProviderRegistry({providers: [provider]});

  const first = registry.loadCatalog();
  const second = registry.loadCatalog();
  await Promise.resolve();
  releaseCatalog();
  await Promise.all([first, second]);

  assert.equal(provider.loadCount, 1);
});

test("duplicate provider keys and malformed voice IDs fail closed", async () => {
  const first = createProvider({key: "duplicate-provider"});
  const second = createProvider({key: "duplicate-provider"});
  assert.throws(
      () => createNarrationProviderRegistry({providers: [first, second]}),
      TypeError,
  );

  const invalidVoiceProvider = createProvider({
    key: "future-provider",
    voices: [{
      id: "invalid:voice",
      name: "Narrator",
      locale: "en-GH",
    }],
  });
  const registry = createNarrationProviderRegistry({
    providers: [invalidVoiceProvider],
  });
  assert.deepEqual(await registry.loadCatalog(), []);
});

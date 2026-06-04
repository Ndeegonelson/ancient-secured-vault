const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createDemoCloudNarrationProvider,
} = require("../narration_demo_provider");
const {
  createNarrationProviderRegistry,
} = require("../narration_provider_registry");
const {
  validateSynthesisResult,
} = require("../narration_gateway");

test("demo provider exposes one clearly labeled safe narrator", async () => {
  const provider = createDemoCloudNarrationProvider();

  const voices = await provider.loadVoices();

  assert.deepEqual(voices, [{
    id: "demo-secure-narrator",
    name: "Demo Secure Narrator",
    locale: "en-GH",
    accent: "Neutral African",
    gender: "Demo",
    style: "Architecture test",
    isCustom: false,
  }]);
});

test("demo provider returns bounded valid in-memory wav audio", async () => {
  const provider = createDemoCloudNarrationProvider();
  const voice = (await provider.loadVoices())[0];
  const request = {
    text: "This is a protected demo narration segment.",
    rate: 1,
    startCharacter: 42,
    voice,
  };

  const result = await provider.synthesize(request);
  const validated = validateSynthesisResult(result, {
    text: request.text,
    voiceId: "demo-provider:demo-secure-narrator",
    rate: request.rate,
    startCharacter: request.startCharacter,
  });
  const audio = Buffer.from(validated.audioBase64, "base64");

  assert.equal(validated.contentType, "audio/wav");
  assert.equal(validated.startCharacter, 42);
  assert.equal(validated.endCharacter, 85);
  assert.equal(audio.toString("ascii", 0, 4), "RIFF");
  assert.equal(audio.toString("ascii", 8, 12), "WAVE");
  assert.ok(validated.durationMilliseconds >= 600);
  assert.ok(validated.durationMilliseconds <= 3000);
});

test("demo timing cues preserve document character offsets", async () => {
  const provider = createDemoCloudNarrationProvider();
  const voice = (await provider.loadVoices())[0];

  const result = await provider.synthesize({
    text: "  First word. Second.",
    rate: 1,
    startCharacter: 100,
    voice,
  });

  assert.deepEqual(result.timingCues.map((cue) => ({
    startCharacter: cue.startCharacter,
    endCharacter: cue.endCharacter,
  })), [
    {startCharacter: 102, endCharacter: 107},
    {startCharacter: 108, endCharacter: 113},
    {startCharacter: 114, endCharacter: 121},
  ]);
});

test("demo provider rejects mismatched internal voice requests", async () => {
  const provider = createDemoCloudNarrationProvider();

  await assert.rejects(
      provider.synthesize({
        text: "Protected demo.",
        rate: 1,
        startCharacter: 0,
        voice: {id: "wrong-voice"},
      }),
      /invalid/,
  );
});

test("demo provider works through the server-owned registry route", async () => {
  const registry = createNarrationProviderRegistry({
    providers: [createDemoCloudNarrationProvider()],
  });

  const catalog = await registry.loadCatalog();
  const result = await registry.synthesize({
    text: "Registry demo narration.",
    voiceId: "demo-provider:demo-secure-narrator",
    rate: 0.8,
    startCharacter: 7,
  });

  assert.equal(catalog.length, 1);
  assert.equal(catalog[0].id, "demo-provider:demo-secure-narrator");
  assert.equal(result.contentType, "audio/wav");
  assert.equal(result.startCharacter, 7);
  assert.equal(result.endCharacter, 31);
});

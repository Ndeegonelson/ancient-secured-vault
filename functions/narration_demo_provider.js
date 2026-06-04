const SAMPLE_RATE = 8000;
const MIN_DURATION_MILLISECONDS = 600;
const MAX_DURATION_MILLISECONDS = 3000;

function createDemoCloudNarrationProvider() {
  const voice = Object.freeze({
    id: "demo-secure-narrator",
    name: "Demo Secure Narrator",
    locale: "en-GH",
    accent: "Neutral African",
    gender: "Demo",
    style: "Architecture test",
    isCustom: false,
  });

  return Object.freeze({
    key: "demo-provider",

    async loadVoices() {
      return [voice];
    },

    async synthesize(request) {
      validateRequest(request, voice.id);
      const durationMilliseconds = durationForText(
          request.text,
          request.rate,
      );
      const audioBuffer = createToneWav({
        durationMilliseconds,
        sampleRate: SAMPLE_RATE,
      });

      return {
        audioBase64: audioBuffer.toString("base64"),
        contentType: "audio/wav",
        startCharacter: request.startCharacter,
        endCharacter: request.startCharacter + request.text.length,
        durationMilliseconds,
        timingCues: createTimingCues({
          text: request.text,
          startCharacter: request.startCharacter,
          durationMilliseconds,
        }),
      };
    },
  });
}

function validateRequest(request, expectedVoiceId) {
  if (!request ||
      typeof request.text !== "string" ||
      request.text.trim() === "" ||
      typeof request.rate !== "number" ||
      !Number.isFinite(request.rate) ||
      !Number.isSafeInteger(request.startCharacter) ||
      request.startCharacter < 0 ||
      !request.voice ||
      request.voice.id !== expectedVoiceId) {
    throw new Error("Demo narration request is invalid.");
  }
}

function durationForText(text, rate) {
  const safeRate = Math.max(0.5, Math.min(rate, 2));
  const estimatedMilliseconds = Math.round(900 + (text.length * 35) / safeRate);
  return Math.max(
      MIN_DURATION_MILLISECONDS,
      Math.min(estimatedMilliseconds, MAX_DURATION_MILLISECONDS),
  );
}

function createToneWav({durationMilliseconds, sampleRate}) {
  const sampleCount = Math.max(
      1,
      Math.floor((durationMilliseconds / 1000) * sampleRate),
  );
  const dataSize = sampleCount * 2;
  const buffer = Buffer.alloc(44 + dataSize);
  let offset = 0;

  offset = writeAscii(buffer, offset, "RIFF");
  offset = writeUInt32(buffer, offset, 36 + dataSize);
  offset = writeAscii(buffer, offset, "WAVE");
  offset = writeAscii(buffer, offset, "fmt ");
  offset = writeUInt32(buffer, offset, 16);
  offset = writeUInt16(buffer, offset, 1);
  offset = writeUInt16(buffer, offset, 1);
  offset = writeUInt32(buffer, offset, sampleRate);
  offset = writeUInt32(buffer, offset, sampleRate * 2);
  offset = writeUInt16(buffer, offset, 2);
  offset = writeUInt16(buffer, offset, 16);
  offset = writeAscii(buffer, offset, "data");
  offset = writeUInt32(buffer, offset, dataSize);

  for (let i = 0; i < sampleCount; i++) {
    const fade = fadeEnvelope(i, sampleCount);
    const sample = Math.sin((2 * Math.PI * 440 * i) / sampleRate);
    buffer.writeInt16LE(Math.round(sample * 5000 * fade), offset);
    offset += 2;
  }

  return buffer;
}

function fadeEnvelope(index, sampleCount) {
  const fadeSamples = Math.max(1, Math.floor(sampleCount * 0.05));
  if (index < fadeSamples) return index / fadeSamples;
  if (index > sampleCount - fadeSamples) {
    return Math.max(0, (sampleCount - index) / fadeSamples);
  }
  return 1;
}

function createTimingCues({text, startCharacter, durationMilliseconds}) {
  const matches = [...text.matchAll(/\S+/g)];
  if (matches.length === 0) return [];

  return matches.map((match, index) => {
    const tokenStart = startCharacter + match.index;
    const tokenEnd = tokenStart + match[0].length;
    const audioOffsetMilliseconds = Math.floor(
        (durationMilliseconds * index) / matches.length,
    );

    return {
      startCharacter: tokenStart,
      endCharacter: tokenEnd,
      audioOffsetMilliseconds,
    };
  });
}

function writeAscii(buffer, offset, value) {
  buffer.write(value, offset, value.length, "ascii");
  return offset + value.length;
}

function writeUInt16(buffer, offset, value) {
  buffer.writeUInt16LE(value, offset);
  return offset + 2;
}

function writeUInt32(buffer, offset, value) {
  buffer.writeUInt32LE(value, offset);
  return offset + 4;
}

module.exports = {
  createDemoCloudNarrationProvider,
};

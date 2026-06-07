const MAX_SYNTHESIS_CHARACTERS = 4500;
const DEFAULT_AUDIO_ENCODING = "MP3";
const DEFAULT_SPEAKING_RATE = 1;

const GOOGLE_TTS_TIMEOUT_MILLISECONDS = 25000;

const GOOGLE_VOICES = Object.freeze([
  Object.freeze({
    id: "en-us-neural-male",
    googleVoiceName: "en-US-Neural2-J",
    name: "Google Neural English Male",
    locale: "en-US",
    accent: "United States",
    gender: "Male",
    style: "Neural",
  }),
  Object.freeze({
    id: "en-us-neural-female",
    googleVoiceName: "en-US-Neural2-F",
    name: "Google Neural English Female",
    locale: "en-US",
    accent: "United States",
    gender: "Female",
    style: "Neural",
  }),
  Object.freeze({
    id: "en-gb-neural-male",
    googleVoiceName: "en-GB-Neural2-B",
    name: "Google Neural UK Male",
    locale: "en-GB",
    accent: "United Kingdom",
    gender: "Male",
    style: "Neural",
  }),
  Object.freeze({
    id: "en-gb-neural-female",
    googleVoiceName: "en-GB-Neural2-A",
    name: "Google Neural UK Female",
    locale: "en-GB",
    accent: "United Kingdom",
    gender: "Female",
    style: "Neural",
  }),
  Object.freeze({
    id: "fr-fr-neural-female",
    googleVoiceName: "fr-FR-Neural2-A",
    name: "Google Neural French Female",
    locale: "fr-FR",
    accent: "France",
    gender: "Female",
    style: "Neural",
  }),
]);

function createGoogleCloudTextToSpeechProvider({
  client,
  voices = GOOGLE_VOICES,
} = {}) {
  let textToSpeechClient = client;
  const voiceById = new Map(voices.map((voice) => [voice.id, voice]));

  return Object.freeze({
    key: "google-cloud-tts",

    async loadVoices() {
      return voices;
    },

    async synthesize(request) {
      const voice = validateRequest(request, voiceById);
      const markedText = createMarkedSsml(request.text);
      const [response] = await withTimeout(
          getClient().synthesizeSpeech({
            input: {ssml: markedText.ssml},
            voice: {
              languageCode: voice.locale,
              name: voice.googleVoiceName,
            },
            audioConfig: {
              audioEncoding: DEFAULT_AUDIO_ENCODING,
              speakingRate: normalizeSpeakingRate(request.rate),
            },
            enableTimePointing: ["SSML_MARK"],
          }),
          GOOGLE_TTS_TIMEOUT_MILLISECONDS,
          "Google Cloud Text-to-Speech did not respond in time.",
      );

      if (!response.audioContent) {
        throw new Error("Google Cloud Text-to-Speech returned no audio.");
      }

      const audioBuffer = Buffer.from(response.audioContent);
      const durationMilliseconds = estimateDurationMilliseconds(
          request.text,
          request.rate,
      );

      return {
        audioBase64: audioBuffer.toString("base64"),
        contentType: "audio/mpeg",
        startCharacter: request.startCharacter,
        endCharacter: request.startCharacter + request.text.length,
        durationMilliseconds,
        timingCues: createTimingCues({
          text: request.text,
          startCharacter: request.startCharacter,
          durationMilliseconds,
          marks: markedText.marks,
          timepoints: response.timepoints,
        }),
      };
    },
  });

  function getClient() {
    if (textToSpeechClient) return textToSpeechClient;
    const textToSpeech = require("@google-cloud/text-to-speech");
    textToSpeechClient = new textToSpeech.TextToSpeechClient();
    return textToSpeechClient;
  }
}

function withTimeout(operation, timeoutMilliseconds, message) {
  return Promise.race([
    operation,
    new Promise((_, reject) => {
      setTimeout(() => reject(new Error(message)), timeoutMilliseconds);
    }),
  ]);
}

function validateRequest(request, voiceById) {
  if (!request || typeof request !== "object") {
    throw new TypeError("Narration request is required.");
  }
  if (typeof request.text !== "string" || request.text.trim() === "") {
    throw new TypeError("Narration text is required.");
  }
  if (request.text.length > MAX_SYNTHESIS_CHARACTERS) {
    throw new RangeError("Narration text exceeds the provider limit.");
  }
  const voice = voiceById.get(request.voice && request.voice.id);
  if (!voice) {
    throw new Error("The selected Google cloud narrator is not available.");
  }
  return voice;
}

function normalizeSpeakingRate(value) {
  if (!Number.isFinite(value)) return DEFAULT_SPEAKING_RATE;
  return Math.min(4, Math.max(0.25, value));
}

function estimateDurationMilliseconds(text, rate) {
  const words = text.trim().split(/\s+/).filter(Boolean).length;
  const wordsPerMinute = 155 * normalizeSpeakingRate(rate);
  return Math.max(1000, Math.ceil((words / wordsPerMinute) * 60 * 1000));
}

function createMarkedSsml(text) {
  const marks = [];
  let ssml = "<speak>";
  let cursor = 0;

  for (const match of createTimingTokenMatches(text)) {
    const token = match[0];
    const tokenStart = match.index;
    const tokenEnd = tokenStart + token.length;
    const markName = `w${marks.length}`;

    ssml += escapeSsml(text.slice(cursor, tokenStart));
    ssml += `<mark name="${markName}"/>`;
    ssml += escapeSsml(token);
    marks.push({
      markName,
      startCharacter: tokenStart,
      endCharacter: tokenEnd,
    });
    cursor = tokenEnd;
  }

  ssml += escapeSsml(text.slice(cursor));
  ssml += "</speak>";

  return {ssml, marks};
}

function createTimingTokenMatches(text) {
  const matches = [];

  for (const match of text.matchAll(/\S+/g)) {
    const token = match[0];
    const tokenStart = match.index;

    if (!shouldSplitTimingToken(token)) {
      matches.push(match);
      continue;
    }

    for (const part of token.matchAll(
        /[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)?/gu,
    )) {
      matches.push({
        0: part[0],
        index: tokenStart + part.index,
      });
    }
  }

  return matches;
}

function shouldSplitTimingToken(token) {
  return token.length > 18 || /(?:https?:\/\/|www\.|@|[./?#=&_-])/.test(token);
}

function escapeSsml(value) {
  return value
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&apos;");
}

function createTimingCues({
  text,
  startCharacter,
  durationMilliseconds,
  marks,
  timepoints,
}) {
  const timedCues = createTimepointTimingCues({
    startCharacter,
    marks,
    timepoints,
  });
  if (timedCues.length > 0) return timedCues;

  return createEstimatedTimingCues({text, startCharacter, durationMilliseconds});
}

function createTimepointTimingCues({startCharacter, marks, timepoints}) {
  if (!Array.isArray(timepoints) || timepoints.length === 0) return [];

  const marksByName = new Map(marks.map((mark) => [mark.markName, mark]));
  return timepoints
      .map((timepoint) => {
        const mark = marksByName.get(timepoint.markName);
        if (!mark || !Number.isFinite(timepoint.timeSeconds)) return null;

        return {
          startCharacter: startCharacter + mark.startCharacter,
          endCharacter: startCharacter + mark.endCharacter,
          audioOffsetMilliseconds: Math.max(
              0,
              Math.floor(timepoint.timeSeconds * 1000),
          ),
        };
      })
      .filter(Boolean);
}

function createEstimatedTimingCues({text, startCharacter, durationMilliseconds}) {
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

module.exports = {
  createGoogleCloudTextToSpeechProvider,
  GOOGLE_VOICES,
};

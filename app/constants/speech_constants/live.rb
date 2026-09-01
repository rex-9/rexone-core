# app/constants/speech_constants/live.rb

module SpeechConstants
  module Live
    TYPE_PARTIAL = "partial".freeze
    TYPE_FINAL = "final".freeze
    TYPE_ERROR = "error".freeze

    PATH_SPEECH_CONFIG = "speech.config".freeze
    PATH_AUDIO = "audio".freeze
    PATH_HYPOTHESIS = "speech.hypothesis".freeze
    PATH_PHRASE = "speech.phrase".freeze

    HEADER_SUBSCRIPTION_KEY = "Ocp-Apim-Subscription-Key".freeze
    HEADER_CONNECTION_ID = "X-ConnectionId".freeze
    AUDIO_CONTENT_TYPE = "audio/x-wav".freeze
    CONFIG_CONTENT_TYPE = "application/json; charset=utf-8".freeze

    AUDIO_SAMPLE_RATE = 16_000
    AUDIO_BITS_PER_SAMPLE = 16
    AUDIO_CHANNELS = 1
    # Azure caps one audio message at 8192 bytes including its header block.
    MAX_AUDIO_CHUNK_BYTES = 4096
    # Live audio has no known length, so the RIFF size fields stay maxed out.
    RIFF_STREAM_SIZE = 0xFFFFFFFF

    RECOGNITION_PATH = "/speech/recognition/conversation/cognitiveservices/v1".freeze
    FORMAT = "simple".freeze
    IDLE_TIMEOUT_SECONDS = 30
    STREAM_PREFIX = "speech_live_user".freeze
  end
end

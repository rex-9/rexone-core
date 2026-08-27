# app/constants/speech_constants/tts.rb

module SpeechConstants
  module Tts
    CONTENT_TYPE = "audio/mpeg".freeze
    FILENAME = "speech.mp3".freeze

    TEXT = "text".freeze
    VOICE_NAME = "voiceName".freeze
    RETURN_FILE = "returnFile".freeze
    AUDIO = "audio".freeze

    # Azure Speech REST synthesis
    AZURE_PATH = "/cognitiveservices/v1".freeze
    AZURE_OUTPUT_FORMAT = "audio-16khz-128kbitrate-mono-mp3".freeze
    AZURE_SSML_CONTENT_TYPE = "application/ssml+xml".freeze
    AZURE_USER_AGENT = "rexone-core".freeze
    HEADER_OUTPUT_FORMAT = "X-Microsoft-OutputFormat".freeze
    HEADER_USER_AGENT = "User-Agent".freeze

    STORAGE_FOLDER = "speech/tts".freeze
    STORAGE_RESOURCE_TYPE = "raw".freeze
  end
end

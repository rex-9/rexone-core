# app/constants/ai_constants/ai_prompt.rb

module AiConstants
  module AiPrompt
    SUMMARIZE        = "Summarize the following text concisely:".freeze
    TRANSLATE        = "Translate the following text to %{language}:".freeze
    DEFAULT_ANALYSIS = "sentiment".freeze
  end
end

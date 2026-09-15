FactoryBot.define do
  factory :ai_profile, class: "Ai::Profile" do
    initialize_with { Ai::Profile.find_or_initialize_by(key: key) }
    key { AiConstants::ProfileKey::CHAT_DEFAULT }
    name { "Default Chat" }
    enabled { true }
    provider { AiConstants::Provider::DEEPSEEK }
    model { "deepseek-chat" }
    temperature { 0.7 }
    max_output_tokens { 2000 }
    context_max_tokens { 8000 }
    history_max_messages { 20 }
    timeout_seconds { 30 }
    settings { {} }
  end

  factory :ai_run, class: "Ai::Run" do
    association :profile, factory: :ai_profile
    user
    feature { AiConstants::RunFeature::CHAT }
    provider { AiConstants::Provider::DEEPSEEK }
    model { "deepseek-chat" }
    status { AiConstants::RunStatus::PROCESSING }
    request_metadata { {} }
  end
end

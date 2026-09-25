require "rails_helper"

RSpec.describe Ai::Providers::Client do
  after do
    described_class.reset_providers!
  end
  it "routes to Gemini provider when requested" do
    fake_gemini = instance_double(Ai::Providers::Gemini)
    allow(Ai::Providers::Gemini).to receive(:new).and_return(fake_gemini)
    allow(fake_gemini).to receive(:chat).and_return("choices" => [ { "message" => { "content" => "Gemini response" } } ])

    result = described_class.chat(provider: "gemini", messages: [ { role: "user", content: "hi" } ])
    expect(result.dig("choices", 0, "message", "content")).to eq("Gemini response")
  end

  it "defaults to DeepSeek provider when no provider is specified" do
    fake_deepseek = instance_double(Ai::Providers::DeepSeek)
    allow(Ai::Providers::DeepSeek).to receive(:new).and_return(fake_deepseek)
    allow(fake_deepseek).to receive(:chat).and_return("choices" => [ { "message" => { "content" => "DeepSeek response" } } ])

    result = described_class.chat(messages: [ { role: "user", content: "hi" } ])
    expect(result.dig("choices", 0, "message", "content")).to eq("DeepSeek response")
  end
end

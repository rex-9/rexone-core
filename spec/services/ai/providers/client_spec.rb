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

  it "routes to DeepSeek provider when requested" do
    fake_deepseek = instance_double(Ai::Providers::DeepSeek)
    allow(Ai::Providers::DeepSeek).to receive(:new).and_return(fake_deepseek)
    allow(fake_deepseek).to receive(:chat).and_return("choices" => [ { "message" => { "content" => "DeepSeek response" } } ])

    result = described_class.chat(provider: "deepseek", messages: [ { role: "user", content: "hi" } ])
    expect(result.dig("choices", 0, "message", "content")).to eq("DeepSeek response")
  end

  it "routes to OpenAI provider when requested" do
    fake_openai = instance_double(Ai::Providers::OpenAi)
    allow(Ai::Providers::OpenAi).to receive(:new).and_return(fake_openai)
    allow(fake_openai).to receive(:chat).and_return("choices" => [ { "message" => { "content" => "OpenAI response" } } ])

    result = described_class.chat(provider: "openai", messages: [ { role: "user", content: "hi" } ])
    expect(result.dig("choices", 0, "message", "content")).to eq("OpenAI response")
  end

  it "routes to Anthropic provider when requested" do
    fake_anthropic = instance_double(Ai::Providers::Anthropic)
    allow(Ai::Providers::Anthropic).to receive(:new).and_return(fake_anthropic)
    allow(fake_anthropic).to receive(:chat).and_return("choices" => [ { "message" => { "content" => "Anthropic response" } } ])

    result = described_class.chat(provider: "anthropic", messages: [ { role: "user", content: "hi" } ])
    expect(result.dig("choices", 0, "message", "content")).to eq("Anthropic response")
  end

  it "raises ArgumentError when provider is missing" do
    expect {
      described_class.chat(messages: [ { role: "user", content: "hi" } ])
    }.to raise_error(ArgumentError, /missing keyword: :?provider/)
  end
end

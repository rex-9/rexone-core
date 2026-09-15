# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Providers::Gemini do
  subject(:provider) { described_class.new }

  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
  end

  it "sends a non-streaming request to gemini OpenAI-compatible endpoint" do
    response = instance_double(Net::HTTPResponse, code: "200", body: { choices: [ { message: { content: "Hello from Gemini" } } ] }.to_json)
    request = nil
    allow(http).to receive(:request) do |value|
      request = value
      response
    end

    result = provider.chat(messages: [ { role: "user", content: "Hi" } ], model: "gemini-2.5-flash", temperature: 0.5, max_tokens: 100)
    expect(result.dig("choices", 0, "message", "content")).to eq("Hello from Gemini")
    expect(request["Authorization"]).to start_with("Bearer ")
    expect(JSON.parse(request.body)).to include("model" => "gemini-2.5-flash", "stream" => false)
  end

  it "returns localized provider error on failure" do
    allow(http).to receive(:request).and_return(instance_double(Net::HTTPResponse, code: "500", body: "error"))
    expect(provider.chat(messages: [] )[:error]).to be_present

    allow(http).to receive(:request).and_raise(Timeout::Error)
    expect(provider.chat(messages: [] )[:error]).to be_present
  end
end

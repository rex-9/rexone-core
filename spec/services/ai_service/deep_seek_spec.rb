require "rails_helper"

RSpec.describe AiService::DeepSeek do
  subject(:provider) { described_class.new }

  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
  end

  it "sends a non-streaming authorized request and parses success" do
    response = instance_double(Net::HTTPResponse, code: "200", body: { choices: [ { message: { content: "Hi" } } ] }.to_json)
    request = nil
    allow(http).to receive(:request) do |value|
      request = value
      response
    end

    result = provider.chat(messages: [ { role: "user", content: "Hello" } ], model: "custom", temperature: 0.2, max_tokens: 50)
    expect(result.dig("choices", 0, "message", "content")).to eq("Hi")

    expect(request["Authorization"]).to start_with("Bearer ")
    expect(JSON.parse(request.body)).to include("model" => "custom", "stream" => false, "max_tokens" => 50)
  end

  it "returns a localized provider error for HTTP and network failures" do
    allow(http).to receive(:request).and_return(instance_double(Net::HTTPResponse, code: "500", body: "bad gateway"))
    expect(provider.chat(messages: [] )[:error]).to be_present

    allow(http).to receive(:request).and_raise(Timeout::Error)
    expect(provider.chat(messages: [] )[:error]).to be_present
  end

  it "yields valid streaming deltas and skips malformed or done chunks" do
    response = double("streaming response")
    chunks = [
      "data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}\n",
      "data: malformed\n",
      "data: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}\n",
      "data: [DONE]\n"
    ]
    allow(response).to receive(:read_body) { |&block| chunks.each(&block) }
    allow(http).to receive(:request).and_yield(response)

    yielded = []
    provider.stream_chat(messages: [], &yielded.method(:<<))
    expect(yielded).to eq(%w[Hel lo])
  end

  it "yields nil when streaming raises" do
    allow(http).to receive(:request).and_raise(IOError, "closed")
    yielded = []
    provider.stream_chat(messages: [], &yielded.method(:<<))
    expect(yielded).to eq([ nil ])
  end
end

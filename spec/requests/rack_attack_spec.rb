require "rails_helper"

RSpec.describe "Rack Attack throttling" do
  subject(:request) { Rack::MockRequest.new(middleware) }

  let(:application) { ->(_env) { [ 200, { "Content-Type" => "application/json" }, [ "{}" ] ] } }
  let(:middleware) { Rack::Attack.new(application) }
  let(:ip) { "203.0.113.10" }

  around do |example|
    original_enabled = Rack::Attack.enabled
    original_store = Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!

    example.run
  ensure
    Rack::Attack.reset!
    Rack::Attack.cache.store = original_store
    Rack::Attack.enabled = original_enabled
  end

  it "throttles sign-in POST requests after ten attempts per IP" do
    10.times do
      expect(request.post("/signin", "REMOTE_ADDR" => ip)).to have_attributes(status: 200)
    end

    response = request.post("/signin", "REMOTE_ADDR" => ip)

    expect(response.status).to eq(429)
    expect(response["Content-Type"]).to eq("application/json")
    expect(response["Retry-After"].to_i).to be_positive
    expect(JSON.parse(response.body)).to include(
      "status" => include("code" => 429, "success" => false),
      "retry_after" => response["Retry-After"].to_i
    )
  end

  it "allows sign-in attempts from another IP" do
    10.times { request.post("/signin", "REMOTE_ADDR" => ip) }

    expect(
      request.post("/signin", "REMOTE_ADDR" => "203.0.113.11")
    ).to have_attributes(status: 200)
  end

  it "throttles /peek GET requests after twelve attempts per IP within 1 minute" do
    12.times do
      expect(request.get("/peek?email=user@example.com", "REMOTE_ADDR" => ip)).to have_attributes(status: 200)
    end

    response = request.get("/peek?email=user@example.com", "REMOTE_ADDR" => ip)

    expect(response.status).to eq(429)
    expect(response["Content-Type"]).to eq("application/json")
    expect(response["Retry-After"].to_i).to be_positive
    expect(JSON.parse(response.body)).to include(
      "status" => include("code" => 429, "success" => false),
      "retry_after" => response["Retry-After"].to_i
    )
  end

  it "throttles /signup POST requests after ten attempts per IP" do
    10.times do
      expect(request.post("/signup", "REMOTE_ADDR" => ip)).to have_attributes(status: 200)
    end

    expect(request.post("/signup", "REMOTE_ADDR" => ip).status).to eq(429)
  end

  it "throttles code dispatch requests after ten attempts per IP" do
    10.times do
      expect(request.post("/confirmation/send_code", "REMOTE_ADDR" => ip)).to have_attributes(status: 200)
    end

    expect(request.post("/confirmation/send_code", "REMOTE_ADDR" => ip).status).to eq(429)
  end

  it "applies the general authentication limit to other auth endpoints" do
    60.times do
      expect(request.get("/password/reset", "REMOTE_ADDR" => ip)).to have_attributes(status: 200)
    end

    expect(
      request.get("/password/reset", "REMOTE_ADDR" => ip)
    ).to have_attributes(status: 429)
  end
end

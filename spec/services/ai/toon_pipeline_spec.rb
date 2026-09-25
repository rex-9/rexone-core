# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Universal Bidirectional JSON <-> TOON AI Pipeline" do
  let(:user) { create(:user) }
  let!(:profile) { Ai::ProfileService.resolve!(AiConstants::ProfileKey::CHAT_DEFAULT) }

  after do
    Ai::Providers::Client.reset_providers!
  end

  describe "Ai::ToonService JSON detection & Inbound Conversion" do
    it "detects JSON in fenced code blocks, bare JSON, and embedded JSON" do
      expect(Ai::ToonService.json_in_text?("```json\n{\"id\": 1}\n```")).to be true
      expect(Ai::ToonService.json_in_text?('{"name": "Rex", "role": "admin"}')).to be true
      expect(Ai::ToonService.json_in_text?('[{"id": 1, "name": "A"}]')).to be true
      expect(Ai::ToonService.json_in_text?('Please inspect {"status": "ok", "code": 200} promptly.')).to be true

      expect(Ai::ToonService.json_in_text?("Hello! How can I help you today?")).to be false
      expect(Ai::ToonService.json_in_text?("See reference [1] and [2] for details.")).to be false
      expect(Ai::ToonService.json_in_text?("")).to be false
      expect(Ai::ToonService.json_in_text?(nil)).to be false
    end

    it "converts markdown fenced JSON blocks into TOON blocks" do
      input = <<~MD
        Here is the configuration:
        ```json
        {
          "service": "rexone-core",
          "port": 3000,
          "enabled": true
        }
        ```
        Please confirm if it is correct.
      MD

      output = Ai::ToonService.json_to_toon(input)

      expect(output).not_to include("```json")
      expect(output).to include("```toon")
      expect(output).to include("service: rexone-core")
      expect(output).to include("port: 3000")
      expect(output).to include("enabled: true")
      expect(output).to include("Here is the configuration:")
      expect(output).to include("Please confirm if it is correct.")
    end

    it "converts bare JSON objects into compact TOON key-value format" do
      json_input = '{"name": "RexOne", "version": "2.0", "status": "active"}'
      toon_output = Ai::ToonService.json_to_toon(json_input)

      expect(toon_output).to include("name: RexOne")
      expect(toon_output).to include('version: "2.0"')
      expect(toon_output).to include("status: active")
      expect(toon_output).not_to include("{")
      expect(toon_output).not_to include("}")
    end

    it "converts bare JSON arrays into TOON tabular format" do
      json_input = JSON.generate([
        { id: 1, name: "Alice", role: "admin" },
        { id: 2, name: "Bob", role: "member" }
      ])
      toon_output = Ai::ToonService.json_to_toon(json_input)

      expect(toon_output).to include("[2]{id,name,role}:")
      expect(toon_output).to include("  1,Alice,admin")
      expect(toon_output).to include("  2,Bob,member")
    end

    it "converts embedded JSON objects within conversational prose" do
      input = 'Please verify this payload: {"user_id": 42, "role": "admin"} and tell me if valid.'
      output = Ai::ToonService.json_to_toon(input)

      expect(output).to include("```toon")
      expect(output).to include("user_id: 42")
      expect(output).to include("role: admin")
      expect(output).to include("Please verify this payload:")
      expect(output).to include("and tell me if valid.")
    end

    it "preserves non-JSON text, citation brackets, and plain conversation" do
      text = "Check items [1] and [chapter 2] before proceeding."
      expect(Ai::ToonService.json_to_toon(text)).to eq(text)
    end
  end

  describe "Ai::ToonService TOON detection & Outbound JSON Conversion" do
    it "detects TOON structures in fenced blocks, bare tables, and key-value maps" do
      expect(Ai::ToonService.toon_in_text?("```toon\nname: Rex\n```")).to be true
      expect(Ai::ToonService.toon_in_text?("[2]{id,name}:\n  1,Alice\n  2,Bob")).to be true
      expect(Ai::ToonService.toon_in_text?("users[2]{id,name}:\n  1,Alice\n  2,Bob")).to be true
      expect(Ai::ToonService.toon_in_text?("name: Rex\nrole: admin")).to be true

      expect(Ai::ToonService.toon_in_text?("Hello! How can I assist you?")).to be false
      expect(Ai::ToonService.toon_in_text?("Note: This is important.")).to be false
    end

    it "converts fenced ```toon blocks into formatted ```json blocks" do
      input = <<~MD
        Here is the user record:
        ```toon
        id: 100
        name: Rex
        roles[2]: admin,developer
        ```
        Let me know if you need more fields.
      MD

      output = Ai::ToonService.toon_to_json(input)

      expect(output).not_to include("```toon")
      expect(output).to include("```json")
      expect(output).to include('"id": 100')
      expect(output).to include('"name": "Rex"')
      expect(output).to include('"roles": [')
      expect(output).to include('"admin"')
      expect(output).to include('"developer"')
      expect(output).to include("Here is the user record:")
      expect(output).to include("Let me know if you need more fields.")
    end

    it "converts bare TOON tabular responses into standard JSON" do
      toon_input = <<~TOON.strip
        users[2]{id,name,role}:
          1,Alice,admin
          2,Bob,member
      TOON

      json_output = Ai::ToonService.toon_to_json(toon_input)
      parsed = JSON.parse(json_output)

      expect(parsed).to eq({
        "users" => [
          { "id" => 1, "name" => "Alice", "role" => "admin" },
          { "id" => 2, "name" => "Bob", "role" => "member" }
        ]
      })
    end

    it "converts bare TOON key-value maps into standard JSON" do
      toon_input = <<~TOON.strip
        name: RexOne
        version: "2.0"
        status: active
      TOON

      json_output = Ai::ToonService.toon_to_json(toon_input)
      parsed = JSON.parse(json_output)

      expect(parsed).to eq({
        "name" => "RexOne",
        "version" => "2.0",
        "status" => "active"
      })
    end

    it "converts embedded bare TOON tables in conversational text into ```json blocks" do
      input = <<~TEXT
        Here is the summary table:

        [2]{id,title,active}:
          1,Task One,true
          2,Task Two,false

        Please let me know how you would like to proceed.
      TEXT

      output = Ai::ToonService.toon_to_json(input)

      expect(output).to include("```json")
      expect(output).to include('"id": 1')
      expect(output).to include('"title": "Task One"')
      expect(output).to include('"active": true')
      expect(output).to include("Here is the summary table:")
      expect(output).to include("Please let me know how you would like to proceed.")
    end

    it "leaves standard conversational text untouched" do
      prose = "Hello! I am ready to help you analyze your application data."
      expect(Ai::ToonService.toon_to_json(prose)).to eq(prose)

      multiline_prose = "Good morning!\nHow can I help you today?"
      expect(Ai::ToonService.toon_to_json(multiline_prose)).to eq(multiline_prose)

      note_prose = "Note: This is important."
      expect(Ai::ToonService.toon_to_json(note_prose)).to eq(note_prose)
    end
  end

  describe "Ai::ToonService.prepare_messages_for_llm" do
    it "converts user JSON to TOON and injects system instruction" do
      messages = [
        { role: "user", content: 'Here is data: {"service": "rexone", "status": "active"}' }
      ]

      prepared = Ai::ToonService.prepare_messages_for_llm(messages)

      # 1. System instruction must be injected
      expect(prepared.first[:role]).to eq(AiConstants::ChatRole::SYSTEM)
      expect(prepared.first[:content]).to include(Ai::ToonService::TOON_SYSTEM_INSTRUCTION)

      # 2. User message must be converted to TOON and contain ZERO raw JSON
      user_msg = prepared.find { |m| m[:role] == "user" }
      expect(user_msg[:content]).to include("```toon")
      expect(user_msg[:content]).to include("service: rexone")
      expect(user_msg[:content]).to include("status: active")
      expect(user_msg[:content]).not_to include('{"service":')
    end

    it "appends TOON system instruction to existing system message when JSON is present" do
      messages = [
        { role: "system", content: "You are a senior Ruby architect." },
        { role: "user", content: '{"action": "refactor", "target": "user_service"}' }
      ]

      prepared = Ai::ToonService.prepare_messages_for_llm(messages)

      system_msg = prepared.find { |m| m[:role] == "system" }
      expect(system_msg[:content]).to start_with("You are a senior Ruby architect.")
      expect(system_msg[:content]).to include(Ai::ToonService::TOON_SYSTEM_INSTRUCTION)
    end

    it "leaves messages unchanged when no JSON is present and instruction is not enforced" do
      messages = [
        { role: "user", content: "What is the capital of France?" }
      ]

      prepared = Ai::ToonService.prepare_messages_for_llm(messages)
      expect(prepared).to eq(messages)
    end

    it "converts raw JSON inside system prompt to TOON" do
      system_content = <<~SYS
        You are a system agent.
        Configuration:
        ```json
        {
          "strict_mode": true,
          "max_retries": 5
        }
        ```
        Follow these constraints.
      SYS

      messages = [
        { role: "system", content: system_content },
        { role: "user", content: "Proceed." }
      ]

      prepared = Ai::ToonService.prepare_messages_for_llm(messages)
      sys_msg = prepared.find { |m| m[:role] == "system" }

      expect(sys_msg[:content]).not_to include("```json")
      expect(sys_msg[:content]).to include("```toon")
      expect(sys_msg[:content]).to include("strict_mode: true")
      expect(sys_msg[:content]).to include("max_retries: 5")
    end
  end

  describe "Ai::ProfileService.prompt_for with unified TOON pipeline" do
    it "converts raw JSON strings passed as template values into TOON" do
      custom_profile = create(:ai_profile, system_prompt: "Context data:\n%{context}\nAnalyze carefully.")
      json_context = '{"services": [{"name": "auth", "port": 3000}, {"name": "db", "port": 5432}]}'

      result = Ai::ProfileService.prompt_for(custom_profile, context: json_context)

      expect(result).not_to include('{"services":')
      expect(result).to include("services[2]{name,port}:")
      expect(result).to include("  auth,3000")
      expect(result).to include("  db,5432")
    end

    it "converts raw JSON embedded directly in system_prompt template into TOON" do
      custom_profile = create(:ai_profile, system_prompt: 'System config: {"env": "production", "debug": false}. Task: %{task}.')
      result = Ai::ProfileService.prompt_for(custom_profile, task: "health_check")

      expect(result).not_to include('{"env":')
      expect(result).to include("env: production")
      expect(result).to include("debug: false")
      expect(result).to include("health_check")
    end
  end

  describe "Ai::Providers::Client gateway enforcement" do
    it "sanitizes messages to TOON before forwarding to concrete provider" do
      fake_deepseek = instance_double(Ai::Providers::DeepSeek)
      allow(Ai::Providers::DeepSeek).to receive(:new).and_return(fake_deepseek)

      allow(fake_deepseek).to receive(:chat) do |kwargs|
        messages = kwargs[:messages]
        messages.each do |msg|
          expect(msg[:content]).not_to include('{"raw": "json"}')
        end
        user_msg = messages.find { |m| m[:role] == "user" }
        expect(user_msg[:content]).to include("raw: json")

        { "choices" => [ { "message" => { "content" => "provider response" } } ] }
      end

      described_class = Ai::Providers::Client
      described_class.chat(messages: [ { role: "user", content: 'Payload: {"raw": "json"}' } ])
    end
  end

  describe "Ai::RunService.execute_chat end-to-end integration" do
    it "ensures LLM provider receives strictly TOON and server receives clean JSON" do
      fake_toon_response = {
        "id" => "resp-999",
        "choices" => [
          {
            "message" => {
              "content" => <<~TOON.strip
                Here is the parsed response:
                ```toon
                status: success
                code: 200
                items[2]{id,name}:
                  1,Item A
                  2,Item B
                ```
                All done!
              TOON
            }
          }
        ],
        "usage" => { "prompt_tokens" => 30, "completion_tokens" => 20, "total_tokens" => 50 }
      }

      allow(Ai::Providers::Client).to receive(:chat) do |kwargs|
        messages_sent_to_provider = kwargs[:messages]

        # LLM MUST NEVER EAT JSON
        messages_sent_to_provider.each do |msg|
          expect(msg[:content]).not_to include('{"tenant":')
          expect(msg[:content]).not_to include('```json')
        end

        # Verifies TOON format was sent
        user_content = messages_sent_to_provider.find { |m| m[:role] == "user" }[:content]
        expect(user_content).to include("tenant: acme")
        expect(user_content).to include("plan: enterprise")

        fake_toon_response
      end

      # User submits JSON in chat message
      user_json_payload = '{"tenant": "acme", "plan": "enterprise"}'

      result = Ai::RunService.execute_chat(
        user: user,
        feature: AiConstants::RunFeature::CHAT,
        profile_key: profile.key,
        messages: [ { role: "user", content: user_json_payload } ]
      )

      # SERVER RECEIVES CLEAN JSON (LLM NEVER HAS TO OUTPUT JSON TO CONSUMERS)
      output_content = result.dig("choices", 0, "message", "content")
      expect(output_content).not_to include("```toon")
      expect(output_content).to include("```json")
      expect(output_content).to include('"status": "success"')
      expect(output_content).to include('"code": 200')
      expect(output_content).to include('"items": [')
      expect(output_content).to include('"name": "Item A"')
      expect(output_content).to include('"name": "Item B"')
      expect(output_content).to include("All done!")

      # Ai::Run record is logged with execution metrics
      run = Ai::Run.last
      expect(run.status).to eq(AiConstants::RunStatus::COMPLETED)
      expect(run.prompt_tokens).to eq(30)
      expect(run.completion_tokens).to eq(20)
      expect(run.total_tokens).to eq(50)
    end
  end

  describe "Full Lossless Round-Trip Consistency" do
    it "preserves complex nested structures across JSON -> TOON -> JSON" do
      original_data = {
        "organization" => "RexOne",
        "active" => true,
        "metrics" => { "cpu" => 12.5, "memory_mb" => 512 },
        "services" => [
          { "name" => "api", "port" => 3000, "healthy" => true },
          { "name" => "web", "port" => 4000, "healthy" => true }
        ]
      }

      json_str = JSON.generate(original_data)
      toon_str = Ai::ToonService.json_to_toon(json_str)
      restored_json = Ai::ToonService.toon_to_json(toon_str)
      parsed_restored = JSON.parse(restored_json)

      expect(parsed_restored).to eq(original_data)
    end
  end
end

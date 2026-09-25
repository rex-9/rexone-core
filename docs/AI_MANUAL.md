# 🧠 RexOne AI Operations & Swapping Manual (`docs/AI_MANUAL.md`)

> **Executive Standard**: AI capabilities in RexOne are completely server-governed, multi-provider, observable, and dynamically swappable without client code deployments or redeployments.

---

## 🏛️ 1. Architectural Overview

```
User / Client Request
        ↓
V1::Chat::MessagesController / V1::Chat::RoomsController
        ↓
Chat::MessageService (Resolves Profile & Queues Run)
        ↓
Chat::ProcessMessageJob
        ↓
Ai::RunService (Telemetry, Monotonic Timing & Audit)
        ↓
Ai::Providers::Client (Swappable Provider Gateway)
    ├── Ai::Providers::DeepSeek (api.deepseek.com)
    └── Ai::Providers::Gemini   (generativelanguage.googleapis.com)
```

1. **Database-Driven Profiles (`Ai::Profile`)**:
   - Every AI behavior (conversational chat, code generation, summarization, translation) is governed by an `Ai::Profile` record.
   - Profile attributes: `key`, `provider` (`"deepseek"`, `"gemini"`), `model`, `temperature`, `max_output_tokens`, `context_max_tokens`, `history_max_messages`, `timeout_seconds`, `system_prompt`, and `settings` (JSONB).
2. **Provider Isolation (`app/services/ai/providers/`)**:
   - Provider integrations are strictly quarantined behind `Ai::Providers::Base` and invoked via `Ai::Providers::Client`.
   - Adding or swapping a provider never leaks HTTP logic into controllers, models, or jobs.
3. **Execution Telemetry (`Ai::Run`)**:
   - Every LLM execution is logged with monotonic latency (`latency_ms`), input character count (`input_chars`), output characters (`output_chars`), prompt/completion/total token usage, and structured error traces if failures occur.

---

## 🔄 2. Swappable AI Providers

RexOne natively supports multiple swappable AI providers:

### 2.1 Google Gemini (`gemini`)

- **API Endpoint**: `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` (OpenAI compatibility REST gateway).
- **Environment Variables**:
  - `GEMINI_API_KEY`: API key generated from Google AI Studio.
  - `GEMINI_BASE_URL`: Defaults to `https://generativelanguage.googleapis.com/v1beta/openai`.
  - `GEMINI_MODEL`: Default model (e.g. `gemini-2.5-flash`, `gemini-1.5-pro`, `gemini-1.5-flash`).

### 2.2 DeepSeek (`deepseek`)

- **API Endpoint**: `https://api.deepseek.com/v1/chat/completions`.
- **Environment Variables**:
  - `DEEPSEEK_API_KEY`: DeepSeek API key.
  - `DEEPSEEK_BASE_URL`: Defaults to `https://api.deepseek.com`.
  - `DEEPSEEK_MODEL`: Default model (e.g. `deepseek-v4-flash`, `deepseek-chat`).

---

## 🧪 3. How to Test, Experiment & Swap Models

### 3.1 Creating an Experimental Profile via Admin Portal

1. Navigate to `/admin/ai/profiles` in the Web Admin Portal.
2. Click **Create Profile** (`/admin/ai/profiles/create`).
3. Fill in the experimental profile parameters:
   - **Key**: Unique slug, e.g. `chat_gemini_experiment`.
   - **Provider**: Select `gemini` or `deepseek`.
   - **Model**: Specify upstream model identifier (e.g. `gemini-2.5-flash` or `deepseek-chat`).
   - **Temperature**: Precision vs. creativity (`0.0` to `2.0`, standard `0.7`).
   - **Max Output Tokens**: Response truncation limit (e.g. `2000`).
   - **Context Max Tokens**: Context window budgeting (e.g. `8000`).
   - **System Prompt**: Specific instructions and personality constraints.
4. Save the profile.

### 3.2 Swapping Active Models in Production

To immediately swap the model or provider for all users:

1. Open `/admin/ai/profiles` and select `chat_default` (or click row to view details).
2. Click **Edit**.
3. Change `provider` from `deepseek` to `gemini` (or vice versa).
4. Update `model` to the desired target model.
5. Click **Save Changes**.
6. **Zero downtime**: All subsequent chat runs will immediately execute against the newly selected provider and model without restarting server containers.

---

## 📊 4. Monitoring & Telemetry (`Ai::Run`)

1. Open `/admin/ai/runs` in the Web Admin Portal.
2. Filter by:
   - **Status**: `completed`, `failed`, `processing`.
   - **Feature**: `chat`, `summarize`, `translate`, `analyze`.
3. Click any row to view **Run Details**:
   - Monotonic Latency (ms).
   - Token breakdown: Prompt Tokens, Completion Tokens, Total Tokens.
   - Message Input Count & Total Characters.
   - Request Metadata (endpoint, user ID, room ID).
   - Complete Error Trace if failed (HTTP status, provider error messages).

---

## 🛡️ 5. Reliability & Fallback Safeguards

1. **Monotonic Timing**: Latency measurements use `Process.clock_gettime(Process::CLOCK_MONOTONIC)` to avoid system clock skew errors.
2. **Provider Timeout Protection**: Every profile enforces a strict `timeout_seconds` (default 30s). Hanging provider connections are cleanly terminated without locking SolidQueue background workers.
3. **Room Concurrency Locks**: Multi-turn rooms are locked during AI generation (`room.with_lock`) to prevent race conditions and duplicate concurrent generations.
4. **Retry Policies**: Background jobs retry transient network errors with exponential backoff on the dedicated `:ai` SolidQueue queue.

---

## ⚡ 6. Universal Bidirectional TOON Pipeline

To achieve 30-60% token savings, lower inference latency, and prevent LLM syntax hallucination, RexOne enforces a universal **Zero-JSON LLM Pipeline**:

```
User / Client (Sends or Types JSON)
                ↓
Chat::MessageService / Chat::ProcessMessageJob
                ↓
Ai::RunService.execute_chat / Ai::Providers::Client.chat
                ↓
Ai::ToonService.prepare_messages_for_llm
  • Inbound Conversion: Markdown ```json, bare JSON, & embedded JSON -> TOON
  • System Directive: Instructs LLM to output strictly in TOON format
                ↓ (LLM NEVER EATS JSON)
Upstream Provider (DeepSeek / Gemini)
                ↓ (LLM NEVER OUTPUTS JSON)
LLM returns completion in TOON format
                ↓
Ai::ToonService.toon_to_json
  • Outbound Conversion: Markdown ```toon, bare tables, & key-value maps -> Clean JSON
                ↓
Server stores standard JSON in Chat::Message & broadcasts via WebSocket
                ↓
Web / Mobile UI receives standard JSON (Clean syntax highlighting & rendering)
```

1. **Inbound JSON Conversion**:
   - Any JSON payload (in user messages, assistant history, system prompts, or template values) is automatically converted to TOON format before reaching the LLM provider.
   - Fenced code blocks (` ```json `) become ` ```toon `, bare JSON objects become compact key-value lines, and arrays become tabular `[N]{fields}:` matrices.
2. **Strict System Prompt Enforcement**:
   - Models are instructed: `Output all structured data, key-value mappings, and tabular records strictly in Token-Oriented Object Notation (TOON) format inside ```toon code blocks. Never output raw JSON.`
3. **Outbound Server Conversion**:
   - When the server receives the completion, `Ai::ToonService.toon_to_json` decodes the TOON structures and transforms them into standard, pretty-printed JSON.
   - Client web applications, mobile apps, and external consumers receive clean JSON without requiring frontend TOON parsers.

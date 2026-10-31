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
    ├── Ai::Providers::DeepSeek  (api.deepseek.com)
    ├── Ai::Providers::Gemini    (generativelanguage.googleapis.com)
    ├── Ai::Providers::OpenAi    (api.openai.com)
    └── Ai::Providers::Anthropic (api.anthropic.com)
```

1. **Database-Driven Profiles (`Ai::Profile`)**:
   - Every AI behavior (conversational chat, code generation, summarization, translation) is governed by an `Ai::Profile` record.
   - Profile attributes: `key`, `provider` (`"deepseek"`, `"gemini"`, `"openai"`, `"anthropic"`), `model`, `temperature`, `max_output_tokens`, `context_max_tokens`, `history_max_messages`, `timeout_seconds`, `system_prompt`, and `settings` (JSONB).
2. **Provider Isolation (`app/services/ai/providers/`)**:
   - Provider integrations are strictly quarantined behind `Ai::Providers::Base` and invoked via `Ai::Providers::Client`.
   - Adding or swapping a provider never leaks HTTP logic into controllers, models, or jobs.
3. **Execution Telemetry (`Ai::Run`) & Database Cost Calculation (`Ai::CostCalculator`)**:
   - Every LLM execution is logged with monotonic latency (`latency_ms`), input character count (`input_chars`), output characters (`output_chars`), prompt/cached/completion/total token usage, USD cost (`cost`), and structured error traces if failures occur.
   - `Ai::CostCalculator` resolves rates directly from active `Ai::Price` records in the database (populated via `Ai::PriceSyncService.sync!` and Admin Portal custom model pricing).

---

## 🔄 2. Swappable AI Providers

RexOne natively supports 4 swappable AI providers (`AI_DEFAULT_PROVIDER` defaults to `deepseek`, and `AI_PRICING_REGISTRY_URL` configures the upstream LiteLLM pricing registry):

### 2.1 Google Gemini (`gemini`)

- **API Endpoint**: `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` (OpenAI compatibility REST gateway).
- **Environment Variables**:
  - `GEMINI_API_KEY`: API key generated from Google AI Studio.
  - `GEMINI_BASE_URL`: Defaults to `https://generativelanguage.googleapis.com/v1beta/openai`.
  - `GEMINI_MODEL`: Default model (e.g. `gemini-2.5-flash`, `gemini-2.5-pro`, `gemini-2.0-flash`).

### 2.2 DeepSeek (`deepseek`)

- **API Endpoint**: `https://api.deepseek.com/v1/chat/completions`.
- **Environment Variables**:
  - `DEEPSEEK_API_KEY`: DeepSeek API key.
  - `DEEPSEEK_BASE_URL`: Defaults to `https://api.deepseek.com`.
  - `DEEPSEEK_MODEL`: Default model (e.g. `deepseek-chat`, `deepseek-reasoner`).

### 2.3 OpenAI (`openai`)

- **API Endpoint**: `https://api.openai.com/v1/chat/completions`.
- **Environment Variables**:
  - `OPENAI_API_KEY`: OpenAI API key.
  - `OPENAI_BASE_URL`: Defaults to `https://api.openai.com/v1`.
  - `OPENAI_MODEL`: Default model (e.g. `gpt-4o-mini`, `gpt-4o`, `gpt-4.1`, `gpt-4.1-mini`).

### 2.4 Anthropic (`anthropic`)

- **API Endpoint**: `https://api.anthropic.com/v1/messages` (native Messages API v1 with `anthropic-version: 2023-06-01`).
- **Environment Variables**:
  - `ANTHROPIC_API_KEY`: Anthropic API key.
  - `ANTHROPIC_BASE_URL`: Defaults to `https://api.anthropic.com`.
  - `ANTHROPIC_MODEL`: Default model (e.g. `claude-sonnet-4-0`, `claude-3-7-sonnet-latest`, `claude-3-5-haiku-latest`).

---

## 🧪 3. How to Test, Experiment & Swap Models

### 3.1 Creating an Experimental Profile via Admin Portal

1. Navigate to `/admin/ai/profiles` in the Web Admin Portal (use **Sync Prices** at any time to pull the latest upstream model rates from the pricing registry).
2. Click **Create Profile** (`/admin/ai/profiles/create`).
3. Fill in the profile parameters:
   - **Key**: Unique slug (e.g. `chat_gemini_experiment`), or click a system preset badge (`chat`, `summarize`, `translate`, `analyze`).
   - **Provider**: Select `deepseek`, `gemini`, `openai`, or `anthropic` (badge indicates whether the provider's API key is configured).
   - **Model**: Select a model from the provider dropdown or choose **Custom Model Identifier** to enter any model identifier and its **Input Rate (\$ / 1M)**, **Cached Rate (\$ / 1M)**, and **Output Rate (\$ / 1M)**.
   - **Temperature**: Precision vs. creativity (`0.0` to `2.0`, standard `0.7`).
   - **Max Output Tokens**: Response truncation limit (e.g. `2000`).
   - **Context Max Tokens**: Context window budgeting (e.g. `8000`).
   - **History Max Messages** & **Timeout (Seconds)**: Conversation history window (`20`) and request timeout (`30`s).
   - **System Prompt**: Specific instructions and personality constraints.
4. Save the profile. Custom profiles can be deleted from the table or detail page when no longer needed, while the 4 system presets (`chat`, `summarize`, `translate`, `analyze`) are protected from deletion.

### 3.2 Swapping Active Models & Adding New Models in Production (Zero Code Changes)

To immediately swap the model or provider, or register a newly released upstream model (e.g. a new Gemini, OpenAI, Anthropic, or DeepSeek model) for all users:

1. Open `/admin/ai/profiles` and select `chat` (or any profile).
2. Click **Edit**.
3. Select the target `provider` (`deepseek`, `gemini`, `openai`, or `anthropic`).
4. Pick a model from the provider models dropdown **or** select **Custom Model Identifier** to type any newly released model identifier (e.g. `gemini-3.0-pro`) and optionally enter or update its **Input Rate ($ / 1M)**, **Cached Rate ($ / 1M)**, and **Output Rate ($ / 1M)**.
5. Click **Save Changes**.
6. **Zero code changes & zero downtime**: `Ai::ProfileService` persists the model on `ai_profiles` and automatically upserts the model and its pricing into `ai_prices` in the database so it immediately appears across all profile dropdowns and filters.

---

## 📊 4. Monitoring & Telemetry (`Ai::Run`)

1. Open `/admin/ai/runs` in the Web Admin Portal.
2. Filter or search by:
   - **Status**: `completed`, `failed`, `processing`.
   - **Feature**: `chat`, `summarize`, `translate`, `analyze`.
   - **Provider**: `deepseek`, `gemini`, `openai`, `anthropic`.
   - **Model**: Any configured or executed model under the selected provider.
   - **Search**: Free-text search across `model`, `feature`, `provider`, and `profile_key`.
3. Click any row to view **Run Details**:
   - Monotonic Latency (`latency_ms`) and USD Cost (`cost`).
   - Token breakdown: Prompt Tokens, Cached Tokens, Completion Tokens, Total Tokens.
   - Message Input Count & Total Input/Output Characters.
   - Request Metadata (endpoint, user ID, room ID, profile key).
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
Upstream Provider (DeepSeek / Gemini / OpenAI / Anthropic)
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

<a id="readme-top"></a>

<div align="center">

# Rexone Core

### A battle-hardened Rails foundation, forged so the product can wage the interesting war.

A production-minded API core for web and mobile products. Authentication, IAM, payments, access control, media, notifications, AI, real-time delivery, background work, administration, and observability stand ready—not as scattered trophies, but as one disciplined system.

Built under a simple creed: **clear in thought, exact in structure, simple in use, and strong enough to endure what comes after launch.**

[![Ruby](https://img.shields.io/badge/Ruby-4.0.4-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1-CC0000?logo=rubyonrails&logoColor=white)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)

**API-first · Modular · Observable · Queue-aware · Built to grow**

[Explore the foundation](#feature-map) · [Ecosystem Architecture](ECOSYSTEM.md) · [Development Law](LAW.md) · [Analytics Guide](ANALYTICS.md) · [Run it locally](#getting-started) · [Open the dashboards](#operations-center) · [Meet the architecture](#architecture)

</div>

---

> [!IMPORTANT]
> **🏛️ Unified Ecosystem**: For the complete cross-platform architecture, feature parity matrix, and communication protocols between Core, Web, and Mobile, see **[ECOSYSTEM.md](ECOSYSTEM.md)**.
>
> **📜 Constitutional Law**: All development must strictly adhere to the architecture, service boundary, and API envelope laws in **[LAW.md](LAW.md)**. Zero exceptions.

## Why Rexone Core?

Every product eventually meets the same old enemies: accounts, permissions, billing, uploads, jobs, notifications, dashboards, audit trails, failures, and the darkness between _“it works”_ and _“we know why it works.”_. Especially, the real challenge is _“it works on my machine.”_

Rexone Core exists because this ground should not have to be conquered again for every product.

This is not a chest of disconnected examples wearing the armor of an architecture. It is a cohesive foundation whose parts answer to one another. Stripe payments grant access. Webhooks are durably recorded before background processing begins. Notifications divide into isolated delivery jobs. Asset cleanup retries without making the client wait. Administrators can inspect the realm, while performance, backend errors, frontend failures, queues, cache, and sockets each leave a trail.

The foundation is designed to **bend around the product**, never to make the product kneel before the framework.

Its boundaries are deliberate and provider-aware. Capabilities can be extended, replaced, or reforged as the product evolves without scattering vendor logic across the codebase.

And no—this was not vibe-coded into existence.

The boundaries were reasoned about. Failure paths were traced. Immediate work was separated from deferred work. Retries, idempotency, observability, security, and data lifecycle were treated as engineering concerns, not decorations added after the demo survived.

Rexone Core brings startup speed with battle-tested discipline—and fewer final-hour whispers of _“we should probably build that before launch.”_

## The philosophy

Rexone Core follows a simple doctrine:

> **Clarity before cleverness. Precision before haste. Simplicity without weakness. Strength without spectacle.**

Years of building software teach the same lesson as any long campaign: the first victory is easy to celebrate; surviving everything that follows is the true test.

The difficult part is rarely another controller or CRUD endpoint. It is preserving a system that remains understandable when the product grows, integrations multiply, failures arrive from unfamiliar directions, and the original developer is no longer the only one carrying the blade.

So the ambition was never to build the largest foundation possible.

It was to build a **clear one**—strong enough to carry ambitious products, flexible enough to surrender its shape to them, and disciplined enough that the next developer can enter the codebase without a map drawn in blood.

No prophecy. No magic. No shortcuts disguised as momentum.

Just deliberate engineering, tested boundaries, and a foundation built to remain standing.

## Feature map

| Foundation     | What is ready                                                                                   | Details                                                |
| -------------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| Identity       | Devise, JWT, confirmation, recovery, Google sign-in, platform sessions                          | [Authentication & security](#authentication--security) |
| Authorization  | Roles, permissions, user-role and role-permission assignments                                   | [IAM & access control](#iam--access-control)           |
| Commerce       | Stripe Checkout, products, transactions, subscriptions, access grants                           | [Payments & entitlements](#payments--entitlements)     |
| Async work     | Solid Queue, dedicated queues, retries, concurrency controls, recurring cleanup                 | [Background processing](#background-processing)        |
| Notifications  | Socket, push, and email coordination through OneSignal and Action Cable                         | [Notifications & real time](#notifications--real-time) |
| Media          | Cloudinary/local providers, uploads, URLs, metadata, queued deletion                            | [Storage & assets](#storage--assets)                   |
| AI             | Durable queued chat, persisted history, completion alerts, and language tools                   | [AI capabilities](#ai-capabilities)                    |
| Localization   | Request-scoped English and Myanmar responses with modular domain translations                   | [Localization](#localization)                          |
| Data lifecycle | PostgreSQL, global soft deletion, actor-aware auditing, JSON:API serialization                  | [Data & API design](#data--api-design)                 |
| Operations     | Performance, errors, client logs, queues, cache, cable, health checks                           | [Observability](#observability)                        |
| Administration | Administrate for Server plus Client Admin API for users, IAM, products, chat, and notifications | [Administration](#administration)                      |
| Delivery       | Docker images, separate API/worker processes, health checks, graceful shutdown                  | [Deployment](#deployment)                              |
| Quality        | RSpec, factories, security scanning, dependency auditing, linting                               | [Quality toolchain](#quality-toolchain)                |

## Architecture

Rexone Core keeps framework concerns conventional and integrations replaceable.

Controllers own HTTP contracts, models own data rules, services own business and provider boundaries, jobs own deferred work, and serializers own response representation.

```mermaid
flowchart LR
    Clients[Web & mobile clients] --> API[Rails API]
    Clients <-->|Action Cable| Realtime[Solid Cable]

    API --> Auth[Authentication & IAM]
    API --> Domain[Product domain]
    API --> Services[Service interfaces]
    API --> Jobs[Solid Queue]

    Domain --> PostgreSQL[(PostgreSQL)]
    Auth --> PostgreSQL
    Jobs --> PostgreSQL

    Services --> Stripe[Stripe]
    Services --> OneSignal[OneSignal]
    Services --> Cloudinary[Cloudinary]
    Services --> DeepSeek[DeepSeek]
    Services --> Speech[Nova · Azure Speech]

    Jobs --> Services
    API --> Observability[Pulse · RED · client logs]
```

Provider-facing code lives behind focused clients such as `PaymentService::Client`, `StorageService::Client`, `AiService::Client`, `SpeechService::Client`, and the notification delivery services.

Swapping or extending a provider does not require spreading vendor logic across controllers.

The same principle applies to product-specific functionality: the foundation provides the structure, while the product remains free to define its own domain, workflows, and experience.

### Background processing

Solid Queue is part of the application architecture, not an afterthought.

The foundation currently queues work where it benefits from durability, isolation, retries, or provider independence:

| Work                             | Queue           | Why                                                             |
| -------------------------------- | --------------- | --------------------------------------------------------------- |
| Stripe webhook processing        | `payments`      | Durable ingestion, idempotency, retries, and concurrency safety |
| Socket, push, and email delivery | `notifications` | Provider latency must not delay the originating request         |
| Physical asset deletion          | `storage`       | Database operations can complete before remote cleanup          |

Production workers are separated by workload in [`config/queue.yml`](config/queue.yml), and recurring maintenance lives in [`config/recurring.yml`](config/recurring.yml).

The queue architecture is intentionally extensible. As a product grows, new workloads can be introduced as dedicated queues with their own concurrency, retry, and execution policies rather than turning the background layer into one undifferentiated worker.

The exact queue structure can also be customized around the requirements of the product being built.

The API and worker run as separate services in Docker, keeping request handling and background execution independently scalable.

## The foundation in detail

### Authentication & security

- Devise authentication with JWT issuance and revocation.
- Email/password registration, confirmation codes, password recovery, locking, tracking, and timeout support.
- Google sign-in with a challenge flow for completing account creation.
- Platform-aware active sessions backed by the application cache.
- Rack Attack throttling for abusive or excessive requests.
- Configurable CORS and Rails security defaults.
- Consistent authentication failures and localized client-facing messages.

Authentication is ready for multiple clients without forcing browser-session assumptions onto an API product.

### IAM & access control

Authorization is modeled explicitly instead of being buried in controller conditionals:

- Users receive roles through `Iam::UserRole`.
- Roles receive resource/action permissions through `Iam::RolePermission`.
- Permissions cover operations such as `create`, `read`, `update`, and `delete`.
- **Three-Tier Administrative Hierarchy & Permission Scoping**:
  - `super_admin`: Full, unrestricted authority across all resources, endpoints, and IAM governance.
  - `admin`: Full operational authority across domain resources (`feedbacks`, `payments`, `ai`, `assets`, `logs`), strictly restricted from managing `users` and `iam`.
  - Partial admins (`*_admin` naming convention): Roles named with the `_admin` suffix (e.g. `feedback_admin`, `payment_admin`) granted to users with the base `user` role.
  - **Permission Provenance & Endpoint Scoping**:
    - **`/v1/admin/*` Endpoints**: Require an admin role (a role whose name contains `admin`) that explicitly grants the required CRUD permission. Permissions inside non-admin roles (such as the base `user` role) cannot grant access to `/v1/admin/*`.
    - **`/v1/*` Endpoints**: Permissions in an admin role (e.g. `read_users` in `user_admin`) grant access to both `/v1/users` and `/v1/admin/users`, whereas permissions in standard user roles only grant access to `/v1/users`.
- New users receive the default user role automatically.

This gives small products a sensible starting policy and growing products a clean path to granular authorization.

### Payments & entitlements

Stripe integration covers the full commercial loop:

- Product and price synchronization.
- Checkout Sessions for one-time purchases and subscriptions.
- Customer creation and reuse.
- Transactions, payment-method metadata, and subscription lifecycle state.
- Cancellation-at-period-end and subscription resumption.
- Access grants and revocation driven by payment state.
- Persisted webhook events with duplicate protection, processing state, attempts, errors, retention, and admin visibility.
- Background webhook processing with targeted retries and per-event concurrency control.

The important distinction is deliberate: customer-facing payment flows remain responsive, while webhook fulfillment is durable and asynchronous for the business.

### Notifications & real time

`NotificationService` coordinates three independent delivery paths:

- Action Cable broadcasts for live in-product updates.
- OneSignal push notifications.
- OneSignal email and template delivery.

Each enabled channel receives its own Solid Queue job. A failed email therefore does not repeat a successful push, and a notification provider outage does not roll back a completed payment or authentication action.

The admin- and permission-protected `POST /v1/admin/notifications` contract is ready for the dashboard to send custom content to confirmed users holding selected roles—or to the full confirmed audience—through any combination of socket, push, and email. Users with several selected roles are included only once. Audience fanout runs in the `notifications` queue, while each resulting channel delivery keeps its own retry boundary. Transactional OneSignal email template identifiers live beside the email provider instead of in application initializers, and sensitive confirmation or password-reset workflows are never exposed as admin-selectable presets.

### Storage & assets

The storage abstraction supports Cloudinary and a local provider with a consistent interface for upload, deletion, URL generation, move, copy, existence checks, and listing.

- Uploads return the URL and metadata the client needs immediately.
- Assets retain provider identifiers, category, media type, extension, size, source, and ownership.
- Remote deletion happens after the database transaction commits.
- Failed deletion is retried and "already absent" is treated idempotently.
- Local paths are constrained to the configured storage root.
- Cloudinary image, video, and raw document resource types are handled separately.

### AI capabilities

The DeepSeek-backed AI layer provides:

- Durable conversational work through Solid Queue's dedicated `ai` queue.
- Persisted rooms, user messages, processing state, and assistant responses—the browser never owns the lifetime of the work.
- Immediate acknowledgement while the AI continues in the background, with one in-flight request allowed per room.
- Safe retries, per-message concurrency control, idempotent completion, and visible failure state.
- Real-time completion and failure alerts through the existing notification socket channel.
- Optional push and email delivery through the same notification path by enabling the existing channel flags.
- Summarization.
- Translation.
- Sentiment, entity, keyword, and general analysis prompts.
- A provider-neutral client boundary for future AI backends.
- Safe client errors with detailed provider failures retained in server logs.

The user can leave the chat, browse elsewhere, close the browser, or shut down the device without interrupting generation. The completed assistant message is committed to conversation history before notification delivery begins, so it is already waiting when the user returns—even if no live socket was present to receive the alert.

The AI layer remains isolated behind its provider boundary so product-specific workflows can evolve without coupling the rest of the application to a single model provider.

### Speech capabilities

The unified speech infrastructure provides both synchronous utilities and real-time streaming audio capabilities:

- **Text-to-Speech (TTS)**:
  - Synchronous binary audio streaming (`POST /v1/speech/tts`) returning raw MP3 data without base64 wrapper overhead.
  - Asynchronous background TTS synthesis for chat messages (`POST /v1/speech/tts` with `message_id`).
  - Durable background processing via `Speech::ProcessTtsJob` on the dedicated `:ai` queue with retry logic and per-message concurrency limits.
  - Automated Cloudinary audio storage and polymorphic `Asset` attachment to chat messages.
  - Real-time `tts_ready` and `tts_failed` completion alerts broadcast over ActionCable (`NotificationChannel`).
- **Speech-to-Text (STT)**:
  - Synchronous transcription (`POST /v1/speech/stt`) accepting either multipart audio file uploads or remote `audio_url` references.
  - Real-time live audio transcription over WebSocket via `SpeechLiveChannel`, streaming PCM audio chunks directly to Azure Speech live recognition sessions.
- **Provider Architecture**:
  - `SpeechService::Client` exposes the generic domain interface while isolating provider specifics behind `NovaSpeech` (batch REST STT/TTS) and `AzureSpeech` (SSML REST TTS & live WebSocket STT).

### Data & API design

- PostgreSQL with UUID primary keys for application records.
- Global soft deletion through Discard, with kept records as the default scope.
- Actor-aware creation, update, discard, and restore auditing through `Current.auditor`.
- JSON:API serializers for stable resource representation.
- A consistent response envelope (`status`, `message`, `data`, `error`, `meta.pagination`) across all standard endpoints.
- Pagy-backed offset pagination unified across all collection and list endpoints.
- Intentionally namespaced constants organized by domain in `app/constants/` (`AiConstants`, `PaymentConstants`, `AccessConstants`, `AssetConstants`, `AuthConstants`, `NotificationConstants`).
- Versioned client routes under `/v1` and a separate admin API namespace.
- Modular I18n-backed client messages, organized by product domain.
- OpenAPI documentation served through Rswag.

### Localization

Client-facing messages are organized by domain through `MessageService` and Rails I18n instead of being collected in one global constants file. English (`en`) and Myanmar (`my`) are included, with English as the safe fallback.

The API selects a locale for each request in this order:

1. Query parameter: `?locale=my`
2. Explicit header: `X-Locale: my`
3. Standard header: `Accept-Language: my-MM`
4. Default: `en`

Locale switching is request-scoped through `I18n.with_locale`, preventing one request's language from leaking into another under concurrent execution. Adding another language means mirroring the modular files in `config/locales` and registering its locale code.

### Observability

Backend, frontend, synchronous, and asynchronous failures leave different clues. Rexone Core gives each one a proper home.

- **Rails Pulse** tracks request, query, and background-job performance with configurable thresholds.
- **Rails Error Dashboard** captures, groups, analyzes, and retains backend exceptions. Optional Slack, email, Discord, PagerDuty, and webhook alerts are supported but disabled by default.
- **Client Logs** accept structured errors from web and mobile clients, including stack traces, platform/device context, severity, occurrences, and resolution state.
- **Solid Web UI** exposes queue, cache, and cable operations.
- **Health checks** are available at `/up` for containers and load balancers.

That is full-stack visibility without requiring an external observability platform on day one.

### Administration

The server-rendered Administrate workspace manages users, assets, access grants, IAM, payments, webhook events, chat data, and client logs.

Admin authentication uses application users over HTTP Basic and requires an `admin` or `super_admin` role.

A separate `/v1/admin` namespace supports the web admin client, exposing versioned endpoints for:

- **User management**: CRUD, search, discard/undiscard, role assignment, self-lifecycle protection, and last-super-admin guard.
- **IAM management**: Role management with permission matrix and permission CRUD with auto-generated names.
- **Chat moderation**: Chat rooms and messages CRUD operations.
- **Product management**: Stripe synchronized products with discard/undiscard operations.
- **Notifications**: Broadcast dispatch with template catalog, multi-channel dispatch, and audience targeting (by roles, users, or all).

### Quality toolchain

- RSpec, FactoryBot, Shoulda Matchers, Faker, and Database Cleaner.
- RuboCop Rails Omakase for consistent Ruby and Rails style.
- Brakeman for Rails security analysis.
- Bundler Audit for dependency vulnerability checks.
- Guard RSpec for rapid local feedback.
- Rswag request specifications for OpenAPI generation.

## Operations center

Operational dashboards are mounted in the application and protected by admin authentication. API documentation and the health endpoint are listed alongside them for convenience.

| Path           | Purpose                             |
| -------------- | ----------------------------------- |
| `/admin`       | Administrate resource management    |
| `/admin/pulse` | Request, query, and job performance |
| `/admin/red`   | Backend errors and diagnostics      |
| `/admin/queue` | Solid Queue inspection and control  |
| `/admin/cache` | Solid Cache inspection              |
| `/admin/cable` | Solid Cable inspection              |
| `/api-docs`    | Swagger/OpenAPI documentation       |
| `/up`          | Application health check            |

Client-side errors are accepted at `POST /v1/log/clients` and managed from the admin area.

## Getting started

Docker is the quickest and most reproducible path.

### Prerequisites

- Docker with Docker Compose
- Git

For a native installation, use Ruby `4.0.4`, PostgreSQL, libvips, and Bundler `4.0.16`.

### 1. Clone and configure

```bash
git clone https://github.com/rex-9/rexone-core.git
cd rexone-core
cp .env.example .env
```

Fill in the required database, JWT, Stripe, OneSignal, DeepSeek, and Cloudinary values in `.env`.

Development placeholders are fine for providers you are not exercising, but never ship placeholder secrets.

### 2. Start the stack

```bash
docker compose -f docker-compose.dev.yaml up --build
```

This starts:

- `api` — Rails on [http://localhost:3000](http://localhost:3000)
- `waka` — the dedicated Solid Queue worker
- `db` — PostgreSQL

The development entrypoint runs `db:prepare` when the API starts.

If you prefer separate terminals, the repository includes:

```bash
./scripts/dev_db.sh
./scripts/dev_api.sh
./scripts/dev_waka.sh
```

### 3. Seed IAM and admin users

```bash
docker compose -f docker-compose.dev.yaml exec api bin/rails db:seed
```

The seed file creates the default roles, permissions, assignments, and development admin accounts.

Review and replace seeded credentials before using them outside local development.

### Useful commands

```bash
# Rails console
./scripts/console.sh

# Generate OpenAPI output
./scripts/rswag.sh

# Run the repository test script
./scripts/test.sh

# Watch specs
./scripts/test_watch.sh

# Run Rails security analysis
bin/brakeman

# Run linting
bin/rubocop
```

## Configuration

The checked-in [`.env.example`](.env.example) documents the available settings.

The important groups are:

- Rails environment, URLs, logging, threads, and secrets.
- PostgreSQL connection and Docker service names.
- JWT/session, confirmation, and password-reset lifetimes.
- Stripe credentials, webhook secret, and redirect URLs.
- OneSignal application, API key, sender, and sound configuration.
- DeepSeek API URL, key, and model.
- Cloudinary credentials or local storage path.
- Solid Queue process and shutdown settings.

Keep real credentials in your deployment platform or encrypted secret store—not in Git.

## API surface

The API is broader than a starter CRUD demo. Its main route families are:

| Area             | Representative routes                                                    |
| ---------------- | ------------------------------------------------------------------------ |
| Authentication   | `/signup`, `/signin`, `/signin/google`, `/confirmation/*`, `/password/*` |
| Users            | `/v1/users/*`                                                            |
| IAM              | `/v1/iam/*`                                                              |
| Admin API        | `/v1/admin/*`                                                            |
| Payments         | `/v1/payment/*`, `/webhooks/stripe`                                      |
| Entitlements     | `/v1/access/*`                                                           |
| Media            | `/v1/media/upload`                                                       |
| Notifications    | `/v1/admin/notifications`                                                |
| AI               | `/v1/ai/*`                                                               |
| Speech           | `/v1/speech/*`, `SpeechLiveChannel` (WS)                                 |
| Client telemetry | `/v1/log/clients`                                                        |

Use `/api-docs` for the interactive OpenAPI view and [`config/routes.rb`](config/routes.rb) for the authoritative route map.

## Deployment

The production image is multi-stage, runs as a non-root user, precompiles Bootsnap, includes health-check dependencies, and prepares the database when the API container starts.

[`docker-compose.yaml`](docker-compose.yaml) separates the API, Solid Queue worker, and PostgreSQL services with health checks and restart policies.

The same image can also be deployed through Kamal or another container platform.

Before production:

1. Supply real secrets through the deployment environment.
2. Use strong, unique admin credentials and remove development seed accounts.
3. Configure Stripe webhook signing and provider callback URLs.
4. Run the API and `bin/jobs` worker as separate processes.
5. Confirm database pool sizing against API threads and queue concurrency.
6. Put TLS and a trusted reverse proxy in front of the application.
7. Review retention, throttling, alerting, and backup policies for your product.

## Related clients

- [Rexone Web](https://github.com/rex-9/rexone-web) — web client
- [Rexone Mobile](https://github.com/rex-9/rexone_mobile) — mobile client

## Support the project

If Rexone Core saves you a few weeks—or saves you from one memorable production incident—consider giving it a star. 🌟

[![GitHub Stars](https://img.shields.io/github/stars/rex-9/rexone-core.svg?style=social&label=Star)](https://github.com/rex-9/rexone-core)

## Author

Built with clarity, curiosity, and a healthy suspicion of unexamined complexity by **Rex (Rex9)**.

A software engineer, full-stack architect, and long-time practitioner of meditation.

I build systems the same way I approach the path itself: **with a clear mind, deliberate steps, and no unnecessary weight.**

- GitHub: [@rex-9](https://github.com/rex-9)
- Portfolio: [rex9.vercel.app](https://rex9.vercel.app)
- LinkedIn: [rex9](https://www.linkedin.com/in/rex9/)

<p align="right"><a href="#readme-top">Back to top ↑</a></p>

# RexOne Core: Technical Documentation & Subsystem Reference

This directory serves as the technical documentation manual for **RexOne Core** (`rexone-core`), the sovereign Ruby on Rails 8 API engine for modern web and mobile applications.

---

## 📚 Documentation Index

| Guide | Description | Canonical Path |
| :--- | :--- | :--- |
| **🚀 Ecosystem Quick Start** | Local containerized setup, database seeding, and startup debugging | **[`docs/QUICK_START.md`](QUICK_START.md)** |
| **🏛️ Foundation Architecture** | Deep dive into IAM, Devise JWT, Soft Deletion, and JSON:API conventions | **[`docs/FOUNDATION.md`](FOUNDATION.md)** |
| **🗺️ Visual Walkthrough** | Screenshot-driven, feature-by-feature tour across all operations | **[`docs/VISUAL_WALKTHROUGH.md`](VISUAL_WALKTHROUGH.md)** |
| **🗄️ Database Schema & Models** | Complete database schema, tables, UUID indexes, and model associations | **[`docs/SCHEMA.md`](SCHEMA.md)** |
| **📦 Object Storage (Garage S3)** | Self-hosted S3-compatible Garage storage setup, buckets, and Cyberduck profile | **[`docs/GARAGE.md`](GARAGE.md)** |
| **🎬 Media Processing & Streaming** | Progressive video/audio playback, FFmpeg background compression, and SRT subtitles | **[`docs/MEDIA_PLAYBACK.md`](MEDIA_PLAYBACK.md)** |
| **🤖 AI Assistant & Speech Manual** | Queued chat, Telegram-style chunking, DeepSeek/Gemini, and TTS/STT pipelines | **[`docs/AI_MANUAL.md`](AI_MANUAL.md)** |
| **📊 Analytics & Telemetry** | Glass-box observability, Rails Pulse APM, RED error tracking, and client logs | **[`docs/ANALYTICS.md`](ANALYTICS.md)** |
| **⚡ Async Operations & Queues** | Solid Queue fiber + thread concurrency topology, recurring jobs, and priority pooling | **[`docs/ASYNC_OPERATIONS.md`](ASYNC_OPERATIONS.md)** |
| **🛡️ Security & Boot Guard** | Zero-trust CORS, startup secret validation, pre-commit scanners, and hygiene | **[`docs/SECURITY.md`](SECURITY.md)** |
| **🛑 DDoS & Rate Limiting** | Edge defense, Rack::Attack rate-limiting ladders, and abuse protection | **[`docs/DDOS.md`](DDOS.md)** |
| **🚀 Production Deployment** | Multi-stage Docker, Coolify VPS maintenance, log rotation, and SSL reverse proxy | **[`docs/DEPLOYMENT.md`](DEPLOYMENT.md)** |
| **🏷️ Naming Conventions** | Canonical identifiers (`storage_key`), parameter rules, and casing conventions | **[`docs/NAMING_CONVENTIONS.md`](NAMING_CONVENTIONS.md)** |

---

## 🛠️ CLI Development Scripts Catalog

All development tasks are automated via deterministic shell scripts located in `scripts/`:

| Script | Purpose | Options / Flags |
| :--- | :--- | :--- |
| `./scripts/dev.sh` | Starts all 5 Core containers (API, DB, Waka worker, Garage S3, Media) | None |
| `./scripts/ci.sh` | Runs full automated test suite (RSpec, API contracts, RuboCop, locales) | `contracts` (run contract validation only) |
| `./scripts/check_locales.sh` | Verifies English & Burmese translation parity and message constants | `--unused` (audit unreferenced keys) |
| `./scripts/console.sh` | Opens an interactive Rails console inside the running API container | None |
| `./scripts/enter_api.sh` | Enters the running API container bash shell or executes arbitrary commands | `[cmd...]` |
| `./scripts/docker_clean.sh` | Safely prunes stopped containers, orphan networks, and build cache (preserves DB) | `-y`, `--force` (bypass prompts), `--volumes` |
| `./scripts/vps_cleanup.sh` | Safe recurring production VPS maintenance for Coolify (prunes images older than 7d) | `IMAGE_RETENTION_HOURS=168` |
| `./scripts/rebrand.sh` | Master rebranding automation across Core, Web, and Mobile ecosystems | `<config.json>` |
| `./scripts/generate_secrets.sh` | Generates high-entropy cryptographically secure production secret keys | None |
| `./scripts/check_secrets.sh` | Pre-commit secret scanner blocking live API keys and untracked `.env` files | `--install`, `--all` |
| `./scripts/install_pre_commit.sh`| Installs the master git pre-commit hook into your local `.git/hooks/` | None |

---

## 🌐 API Route Directory

For interactive OpenAPI/Swagger exploration, visit `/api-docs` when the API is running. The authoritative route families defined in [`config/routes.rb`](../config/routes.rb) include:

* **Authentication (`/signup`, `/signin`, `/confirmation/*`, `/password/*`)**: Stateless Devise JWT, OTP email verification, atomic JTI revocation lists, and Google OAuth challenge exchanges.
* **IAM & Users (`/v1/users/*`, `/v1/iam/*`)**: Hierarchical role assignments, resource permission grids, user profile updates, and active session management.
* **Commerce (`/v1/payment/*`, `/webhooks/stripe`)**: Stripe Checkout sessions, coupon validation with progressive cooldown ladders, subscription state machines, and webhook event handlers.
* **Entitlements (`/v1/access/*`)**: Product access grant checks, manual access management, and entitlement expiration calculations.
* **Media & Subtitles (`/v1/assets/*`)**: Pre-signed S3 upload tickets, polymorphic asset tracking, silent background transcoding, and raw SRT/WebVTT subtitle streaming.
* **Operational Admin API (`/v1/admin/*`)**: Full-page administrative management for users, roles, products, batch coupon generation, user coupons ledger, notification broadcasts, asset control, and chat moderation.
* **AI & Speech (`/v1/chat/*`, `/v1/speech/*`)**: Durable queued chat sessions, Telegram-style multi-chunking, swappable LLM provider execution (DeepSeek, Gemini), and TTS/STT audio streaming.
* **Client Telemetry (`/v1/client/logs`)**: Structured diagnostic ingestion for uncaught web and mobile exceptions.
* **Client Versions (`/v1/client/versions/current`)**: Semver release comparison with force and skippable in-app update prompts.

---

## ⚙️ Concurrency & Background Topologies

Core implements a hybrid **Fiber + Thread** concurrency model via Solid Queue and Ruby Fibers:
- **I/O Worker (Fibers)**: 50 concurrent fibers handling Stripe webhooks, LLM streaming, push/email dispatch, and real-time WebSockets without thread exhaustion.
- **System Worker (Threads)**: 2 isolated OS threads executing transactional database maintenance cron (`config/recurring.yml`).
- **Media Worker (Threads)**: Dedicated isolated container running FFmpeg and libvips to prevent CPU-intensive video compression from starving I/O throughput.

For full architectural details, review **[`docs/ASYNC_OPERATIONS.md`](ASYNC_OPERATIONS.md)**.

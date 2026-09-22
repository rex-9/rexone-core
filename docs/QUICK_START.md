# RexOne Ecosystem Quick Start

This is the shortest supported path from a clean checkout to a running RexOne Core API. Core can run independently; RexOne Web and RexOne Mobile are optional reference clients.

## Compatibility

RexOne is currently developed as a coordinated source ecosystem rather than a set of independently versioned stable releases.

| Component                                               | Supported integration branch | Role                                                | Contract authority                    |
| ------------------------------------------------------- | ---------------------------- | --------------------------------------------------- | ------------------------------------- |
| [RexOne Core](https://github.com/rex-9/rexone-core)     | `dev`                        | API, business logic, persistence, queues, providers | OpenAPI, sockets, and server behavior |
| [RexOne Web](https://github.com/rex-9/rexone-web)       | `dev`                        | React reference client and admin portal             | Core contracts plus Web `LAW.md`      |
| [RexOne Mobile](https://github.com/rex-9/rexone_mobile) | `dev`                        | Flutter reference client for Android and iOS        | Core contracts plus Mobile `LAW.md`   |

Use the three `dev` branches together for the supported development integration line. A feature branch is provisional and may require corresponding client changes until it is merged into `dev`. Core's generated OpenAPI document is authoritative for HTTP operations; [ECOSYSTEM.md](../ECOSYSTEM.md) defines cross-platform ownership, socket events, and shared behavior.

## Prerequisites

- Git
- Docker with Docker Compose

For a native Core installation, use Ruby 4.0.4, PostgreSQL 18, libvips, FFmpeg, `librsvg2-bin`, and Bundler 4.0.16.

## 1. Clone, configure, and secure Core

```bash
git clone https://github.com/rex-9/rexone-core.git
cd rexone-core
git switch dev
cp .env.example .env

# Install master pre-commit security & quality hooks (MANDATORY)
./scripts/install_pre_commit.sh
```

### 🛡️ Pre-Commit Safety Guardrail
**Running `./scripts/install_pre_commit.sh` is mandatory before making any commits.** It installs local Git hooks that automatically prevent committing unignored `.env` files, high-entropy cloud keys (Stripe, AWS, OpenAI, Google), and unlocalized strings. See [Security Architecture](SECURITY.md) for full details.

## Configure Core

The checked-in [`.env.example`](../.env.example) is the authoritative catalog of available settings. Review the copied `.env` and configure the providers and processes you intend to run.

The main configuration groups are:

- Application environment, URLs, logging, ports, threads, and Rails secrets.
- PostgreSQL connection and process-specific connection pools for API, Waka, and media workers.
- JWT sessions, confirmation codes, and password-reset lifetimes.
- Storage provider selection and Garage S3, Cloudinary, or local-storage settings.
- Media enablement, upload limits, and image, video, and audio processing profiles.
- Stripe credentials, webhook signing secret, and checkout redirect URLs.
- Brevo email delivery settings and OneSignal push delivery settings.
- DeepSeek AI and Nova/Azure speech provider settings.
- Solid Queue process and shutdown behavior.
- Client-version store URLs and observability metadata.

Development placeholders are acceptable for providers you are not exercising. They are not acceptable in a deployed environment. Keep production credentials in the deployment platform or an encrypted secret store rather than Git.

Configuration determines which services are enabled:

- `STORAGE_PROVIDER=garage` enables self-hosted Garage S3 storage.
- Enabling Core media processing boots the dedicated media-worker.
- Local Stripe webhook handling requires the Stripe CLI forwarding process.
- Alternative storage/media providers should run their own required local services instead.

## 2. Start Core with Docker (Recommended)

When Docker is installed, you do **not** need six terminals. All Core services (PostgreSQL, Rails 8 API, Solid Queue workers, self-hosted Garage S3 storage, and media processor) boot together cleanly in a single script:

```bash
./scripts/dev.sh
# (runs: docker compose -f docker-compose.dev.yaml up)
```

This automatically orchestrates:

- **`db`**: PostgreSQL database with automated healthchecks.
- **`api`**: Rails 8 API server on `http://localhost:3000` (auto-runs `db:prepare`).
- **`waka`**: Solid Queue general background worker for asynchronous jobs.
- **`garage`**: Self-hosted S3-compatible object storage on `http://localhost:3100`.
- **`media`**: Dedicated media worker processing video/audio/image pipelines.

### The Only Optional Terminal: Stripe Webhook Forwarding

If you are developing or testing Stripe billing and subscriptions locally, open **one optional terminal** to run the Stripe CLI forwarder:

```bash
./scripts/listen_webhook.sh
```

---

### Alternative: Granular Process Isolation (Advanced Debugging)

For developers who require isolated stdout streams or individual service restarts during low-level engine debugging, Core also provides individual scripts for each responsibility:

| Terminal     | Command                       | Responsibility                               | When required                      |
| ------------ | ----------------------------- | -------------------------------------------- | ---------------------------------- |
| 1            | `./scripts/dev_db.sh`         | PostgreSQL database                          | Always                             |
| 2            | `./scripts/dev_api.sh`        | Rails API at `http://localhost:3000`         | Always                             |
| 3            | `./scripts/dev_waka.sh`       | General Solid Queue worker                   | Always for queued application work |
| 4            | `./scripts/dev_garage.sh`     | Garage S3 storage at `http://localhost:3100` | When `STORAGE_PROVIDER=garage`     |
| 5            | `./scripts/dev_media.sh`      | Image, video, audio, and thumbnail worker    | When the media service is enabled  |
| 6 (Optional) | `./scripts/listen_webhook.sh` | Stripe CLI webhook forwarding                | When using Stripe locally          |

Garage and the media worker are not required when the application uses another file-storage provider without Core's media pipeline. Stripe CLI forwarding is not required when Stripe is disabled or another payment gateway is used.

Start the database before the API when running scripts individually. Core runs `db:prepare` when the API starts; wait until the API and database are ready before seeding.

## 3. Seed IAM and development users

```bash
docker compose -f docker-compose.dev.yaml exec api bin/rails db:seed
```

The seed task creates default roles, permissions, assignments, and development accounts. Read the seed output for the current local credentials and replace development credentials before any non-local deployment.

## 4. Verify the API

Open:

- Health check: [http://localhost:3000/up](http://localhost:3000/up)
- OpenAPI UI: [http://localhost:3000/api-docs](http://localhost:3000/api-docs)
- Super-admin record dashboard: [http://localhost:3000/admin](http://localhost:3000/admin)

A successful `/up` response confirms the API process is reachable. It does not by itself verify every optional provider.

## 5. Add RexOne Web

In another terminal:

```bash
git clone https://github.com/rex-9/rexone-web.git
cd rexone-web
git switch dev
cp .env.example .env
./scripts/dev.sh
```

Configure the Web environment to use the local Core HTTP and Action Cable endpoints documented in its `.env.example`. The development script starts the Web Docker environment and prints the client URL.

## 6. Add RexOne Mobile

In another terminal:

```bash
git clone https://github.com/rex-9/rexone_mobile.git
cd rexone_mobile
git switch dev
flutter pub get
flutter run --dart-define=APP_ENV=.env.dev
```

Create and configure `.env.dev` before running. Android emulators, iOS simulators, and physical devices use different host addressing for a Core process running on the development machine.

## Expected evaluation flow

After Core and Web are connected, a useful first evaluation is:

1. Sign in with a seeded development account.
2. Open the Web administration portal.
3. Confirm navigation reflects the account's IAM permissions.
4. Upload a supported asset.
5. Observe its queued/processing state and real-time completion notification while `media` is running.
6. Inspect the API contract at `/api-docs` and the resulting record in the permitted administration interface.

This verifies authentication, IAM, API transport, PostgreSQL, Garage, Solid Queue, Action Cable, and the Web operation lifecycle in one connected workflow.

## Useful Core commands

```bash
# Complete Core CI suite
./scripts/ci.sh

# OpenAPI, channel, and socket contracts
./scripts/ci.sh contracts

# English/Myanmar locale and MessageService parity (add --unused to audit unreferenced keys)
./scripts/check_locales.sh [--unused]

# Rails console
./scripts/console.sh

# Enter running API container shell (or execute custom commands)
./scripts/enter_api.sh [cmd...]

# Reset development database (safeguarded; use -y / --force to bypass confirmation prompt)
./scripts/db_reset.sh [-y]

# Prune containers and dev data volumes (safeguarded; use -y / --force to bypass confirmation prompt)
./scripts/docker_clean.sh [-y]

# Regenerate OpenAPI
./scripts/rswag.sh

# Watch specs
./scripts/test_watch.sh
```

For developers using granular process isolation instead of Docker Compose, the development scripts are `scripts/dev_db.sh`, `scripts/dev_api.sh`, `scripts/dev_waka.sh`, `scripts/dev_garage.sh`, `scripts/dev_media.sh`, and `scripts/listen_webhook.sh`.

## Troubleshooting

### Core is reachable but queued work never completes

Confirm the relevant worker is running. General application work uses `waka`; image, video, audio, and thumbnail work uses `media`.

### Uploads fail or generated media is unavailable

Confirm Garage is healthy and that the S3 endpoint, public endpoint, bucket, credentials, and environment prefix agree with `.env.example`. See [GARAGE.md](GARAGE.md).

### Web cannot authenticate or receive live updates

Confirm both the HTTP API URL and Action Cable URL point to the running Core environment. Verify CORS and allowed origins rather than disabling browser security.

### An optional provider fails

Stripe, Brevo, OneSignal, Google, DeepSeek, Cloudinary, Nova, and Azure require valid provider credentials for their respective flows. A provider-specific failure does not imply that the base Core stack failed to start.

## Next reading

- [Foundation capabilities](FOUNDATION.md)
- [Ecosystem architecture](../ECOSYSTEM.md)
- [Development law](../LAW.md)
- [Production deployment](DEPLOYMENT.md)
- [DDoS and abuse protection](DDOS.md)
- [Asynchronous operation contract](ASYNC_OPERATIONS.md)

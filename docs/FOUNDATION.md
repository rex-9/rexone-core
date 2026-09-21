# RexOne Foundation Guide

This guide contains the detailed capability map for RexOne Core. For installation, use the [Ecosystem Quick Start](QUICK_START.md). For authoritative cross-client contracts and ownership boundaries, use [ECOSYSTEM.md](../ECOSYSTEM.md).

## Authentication and security

- Devise authentication with JWT issuance and revocation.
- Email/passcode registration, confirmation codes, recovery, locking, tracking, and timeout support.
- Google sign-in with a challenge flow for completing new accounts.
- Profile management with validated name and username updates.
- Isolated active sessions for Web, Android, and iOS.
- Rack Attack throttling, configurable CORS, localized failures, and Rails security defaults.

Authentication routes remain separate from IAM-protected `/v1` resources. See [LAW.md](../LAW.md) for the authentication and authorization boundaries.

## IAM and access control

Users receive roles through `Iam::UserRole`; roles receive resource/action permissions through `Iam::RolePermission`. Authorization resolves controller actions to `create`, `read`, `update`, or `delete`.

The administrative hierarchy is:

- `super_admin` has complete system authority.
- `admin` has broad operational authority but cannot govern users, IAM, versions, or user-version records.
- Scoped roles ending in `_admin` expose only explicitly assigned administrative permissions.
- Permissions from ordinary roles never grant access to `/v1/admin/*`.

The serialized current user includes the IAM structure required by Web and Mobile to render permission-aware experiences. Core remains the enforcement authority; client visibility is not a security boundary.

## Payments and entitlements

The Stripe integration covers:

- Product and price synchronization.
- Checkout Sessions for one-time and recurring purchases.
- Customer creation and reuse.
- PaymentIntent transaction snapshots and payment-method metadata.
- Stripe-version-aligned subscription item snapshots.
- End-of-period cancellation and subscription resumption.
- Access grants and revocation driven by payment state.
- Durable, idempotent webhook ingestion and queued processing.

Customer-facing checkout stays responsive while fulfillment and reconciliation run through the dedicated `payments` queue.

## Notifications and real-time delivery

`NotificationService` coordinates independent socket, push, and email delivery. Socket delivery uses Action Cable, push delivery uses OneSignal, and email delivery uses `EmailService` (supporting Brevo and OneSignal). All emails are dynamically structured using the unified cyber-glass **Alert Center Master Shell** (`TemplateRenderer`), supporting open-ended campaign variables, highlight code boxes, receipt grids, and call-to-action buttons without touching code. Relative links (e.g. `/home`, `/payment`) are automatically resolved to full client URLs via `AppConfig.client_url` (`RAILS_CLIENT_BASE_URL`), preventing broken email links, and static HTML files on disk are completely eliminated. Each channel has its own retry boundary, so one provider failure does not repeat successful channels or roll back the originating business action.

Persistent `UserNotification` records provide the in-app inbox, immutable delivery snapshots, read state, and cumulative delivery metrics. Client-visible asynchronous work follows the stable lifecycle:

```text
queued -> processing -> completed | failed
```

Every tracked operation carries a stable operation ID and resource link. See [Asynchronous Operations](ASYNC_OPERATIONS.md) for the complete contract.

## Storage and assets

`StorageService::Client` provides a provider-neutral boundary for Garage S3, Cloudinary, and local storage. Domain records use `storage_key`; provider-specific identifiers do not leak into application models.

Garage is the default provider and partitions new objects under `dev/`, `uat/`, or `prod/`. Asset records and database administration remain environment-agnostic. User objects use `user/{user_id}/...`; platform objects use `admin/...` inside the environment partition.

The asset system supports:

- Polymorphic ownership and provider-neutral metadata.
- Signed inline and download URLs.
- Soft deletion, restoration, batch lifecycle operations, and permanent storage cleanup.
- Super-admin Garage partition and VPS capacity statistics.
- Image, video, and audio optimization through the dedicated `media` queue.
- SVG-to-PNG conversion in the dedicated `media` queue after the original upload is stored.
- Canonical video thumbnails and administrator-supplied video/audio covers.
- Replaceable SRT subtitle assets attached to video and audio parents.
- Progressive audio/video playback through Core-authorized short-lived storage URLs.
- Real-time processing status and operation notifications.

See the [Garage Guide](GARAGE.md) for storage topology, configuration, backups, and operational tooling. See [Media Playback](MEDIA_PLAYBACK.md) for the implemented playback contract and client boundary.

## AI and speech

AI chat persists the user message and queues provider work instead of tying generation to a browser or device connection. Rooms expose durable queued, processing, completed, and failed states. Completed responses are stored before notification delivery.

The provider-neutral AI boundary also supports summarization, translation, sentiment, entity, keyword, and general analysis workflows.

Speech capabilities include:

- Synchronous MP3 text-to-speech responses.
- Asynchronous chat TTS with durable assets and completion alerts.
- Multipart or URL-based speech-to-text.
- Live PCM transcription through `SpeechLiveChannel` and Azure Speech sessions.
- Nova and Azure implementations behind `SpeechService::Client`.

## Data and API design

- PostgreSQL with UUID application-record identifiers.
- Global soft deletion through Discard.
- Actor-aware creation, update, discard, and undiscard auditing.
- JSON:API serializers inside the standard RexOne response envelope.
- Pagy offset pagination for every collection endpoint.
- Versioned client routes under `/v1` and a separate `/v1/admin` namespace.
- Request-scoped Rails I18n messages organized by domain.
- Rswag-generated OpenAPI documentation at `/api-docs`.
- UTC-only persistence and transport; clients own local-time presentation.

See [SCHEMA.md](SCHEMA.md) for application records and [LAW.md](../LAW.md) for the binding architectural rules.

## Client versions and analytics

The public client-version check compares a supplied semantic version with the current published release and returns optional-update, forced-update, beta-ahead, and platform store information. Signed-in clients record one current version snapshot per user and platform.

Behavioral product analytics remains in Firebase/GA4. Core owns the shared `action_noun` event and parameter vocabulary while authoritative payment, access, subscription, and operational data stays in PostgreSQL. See [Analytics](ANALYTICS.md).

## Observability and administration

Operational surfaces include:

- Rails Pulse for request, query, and job performance.
- Rails Error Dashboard for backend exceptions.
- Structured Web and Mobile client error ingestion.
- Solid Web interfaces for queue, cache, and cable operations.
- Container and load-balancer health checks at `/up`.
- Administrate for super-admin infrastructure and record inspection.
- A versioned JSON admin API consumed by RexOne Web's permission-aware portal.

## Quality toolchain

RexOne Core uses RSpec, FactoryBot, Shoulda Matchers, Faker, Database Cleaner, RuboCop Rails Omakase, Brakeman, Bundler Audit, and Rswag contract tests. The canonical local entry point is `./scripts/ci.sh`.

Passing tests are a required baseline, not a substitute for production integration testing of external providers and infrastructure.

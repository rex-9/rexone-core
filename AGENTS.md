# Repository Instructions — rexone-core

Rails 8.1 API backend for Rexone. Runtime is Ruby `4.0.4`, PostgreSQL `18`, Solid Queue/Cable/Cache, Devise JWT, Discard, Audited, JSONAPI Serializer, Pagy, RSpec, and Docker.

## Before Any Backend Change

Always read this `AGENTS.md` first before running merge, pull, edit, test, or implementation commands in this repository.

Read this file before editing backend code. Then inspect the relevant route-to-controller-to-service-to-model flow before changing behavior.

For changes touching a domain, inspect the nearby files first:

- Controller under `app/controllers/v1/**` or `app/controllers/webhooks/**`
- Model under `app/models/**`
- Serializer under `app/serializers/**`
- Service boundary under `app/services/**`
- Constants under `app/constants/**`
- Message/localization service under `app/services/message_service/**`
- Job under `app/jobs/**` when work is async
- Factory/spec under `spec/**`
- OpenAPI docs under `spec/openapi/**` when the API contract changes

Do not infer a backend contract from the frontend. The Rails API is authoritative for IDs, amounts, permission checks, state transitions, and provider behavior.

## Architecture Boundaries

- Controllers own HTTP contracts: params, authorization, response status, and calling services/models.
- Models own persistence rules, associations, enums, scopes, lifecycle callbacks, and domain predicates.
- Services own business workflows and provider boundaries.
- Jobs own deferred/retryable work. Jobs should be idempotent where possible.
- Serializers own response representation. Do not build serializer-shaped hashes in controllers unless the surrounding code already requires it.
- Constants modules own shared enum/string values for domain events, statuses, modes, and channels.
- `MessageService::*` owns client-facing localized messages. Do not hardcode repeated response text in controllers.
- Admin dashboard code under `app/dashboards/**` is separate from versioned JSON APIs.

Canonical request flow:

```text
client -> v1 controller -> service/model -> serializer -> localized JSON response
```

Canonical async flow:

```text
controller/webhook -> durable DB record -> Solid Queue job -> service -> model updates -> notification/socket if needed
```

Provider boundary flow:

```text
controller/job -> <Domain>Service::Client -> provider implementation -> external API
```

Examples:

- Payments: `PaymentService::Client -> PaymentService::Stripe`
- AI: `AiService::Client -> AiService::DeepSeek`
- Storage: `StorageService::Client -> StorageService::Cloudinary` or local provider
- Socket: `SocketService::Client -> SocketService::ActionCable`
- Push/email: `PushNotiService::Client`, `EmailService::Client`, and `NotificationService`

## API Conventions

- Versioned JSON APIs live under `app/controllers/v1/**`.
- Admin APIs live under `app/controllers/v1/admin/**`.
- Webhooks live under `app/controllers/webhooks/**`.
- Use the existing `render_json_response` response envelope.
- Use Pagy for paginated list endpoints, matching nearby controllers.
- Use serializers for API output.
- Respect `X-Locale` / `Accept-Language` localization behavior and existing message keys.
- Respect `X-Platform` session validation behavior.
- Keep request params explicit with strong params.
- Keep API field naming consistent with existing backend wire format. Do not silently rename fields without coordinating serializers, OpenAPI docs, and clients.

## Authentication, IAM, And Admin Access

- Devise/JWT authentication is centralized in application controllers and concerns. Do not duplicate token parsing.
- Permissions are role/action/resource based. Use existing `authorize_action!`, `user.can?`, and related controller patterns.
- Admin endpoints must enforce the matching permission resource/action.
- Super-admin-only behavior should follow existing IAM role patterns.
- Do not bypass permission checks in service objects to make tests easier; set up the right user, role, and permission in specs.

## Models And Data Lifecycle

- Tables use UUID primary keys.
- Soft deletion uses Discard where configured. Prefer `with_discarded` only where restoring/admin/history behavior requires it.
- Auditing uses current actor context. Preserve actor-aware create/update/discard behavior.
- Keep domain predicates on models when they describe persisted state (`free?`, `recurring?`, `active?`, etc.).
- Keep provider IDs unique and present when the model is synced with an external provider.
- Do not remove existing data lifecycle callbacks without checking jobs, admin APIs, and serializers that depend on them.

## Services

- Use focused service classes/modules for domain workflows.
- Keep external-provider code out of controllers and models.
- Preserve provider-neutral client wrappers (`PaymentService::Client`, `StorageService::Client`, etc.).
- Service methods should return domain objects or small result hashes consistent with nearby methods.
- Do not rescue broadly unless the service boundary already handles provider errors and returns an expected error shape.
- Log provider failures with enough context for operations, but keep client-facing errors safe.

## Background Jobs And Webhooks

- Webhook controllers should verify signatures and persist durable event records before background processing.
- Solid Queue jobs should raise on processing failures when retry behavior is desired.
- Webhook processors should be idempotent and tolerate duplicate provider events.
- Notification fanout should keep channel failures isolated.
- Storage deletion should be safe to retry and treat already-absent remote assets as a successful terminal state where appropriate.
- Do not move slow provider calls into request controllers unless the user-facing workflow requires synchronous completion.

## Payments And Stripe

Payment code is especially sensitive. Before changing it, inspect:

- `app/services/payment_service/stripe.rb`
- `app/services/payment_service/client.rb`
- `app/models/payment/**`
- `app/jobs/payment/process_webhook_job.rb`
- `app/controllers/webhooks/stripe_controller.rb`
- `app/controllers/v1/payment/**`
- `app/controllers/v1/admin/payment/**`
- `spec/services/payment_service/**`
- `spec/requests/**/payment/**`

Rules:

- Stripe and the local database should agree after create/update service calls complete.
- Do not rely on a later webhook as the first moment an admin-created product exists locally.
- Webhooks still sync and reconcile state, but admin create/update should persist the local product synchronously after Stripe succeeds.
- Free products are Stripe-backed products with a zero price.
- Free products mean lifetime access: `price_unit_amount = 0`, `cycle = nil`, and no Stripe recurring interval.
- Premium products use Stripe-backed non-zero prices and may be one-time or recurring.
- Do not reintroduce sentinel IDs such as `local_free_product`.
- Product updates that change price/currency/cycle should create a replacement Stripe Price, update the Stripe Product default price, archive the old Stripe Price, and persist the new local `stripe_price_id`.
- Stripe Checkout is not used for free products.
- The backend is authoritative for prices, product IDs, checkout/session state, subscriptions, transactions, and access grants.
- Never let frontend-submitted amounts become authoritative for checkout/payment flows without validating against local persisted products.

## Access And Entitlements

- Access grants should come from successful payment/subscription state or explicit backend rules.
- Lifetime/free access should not expire unless a separate revocation flow says so.
- Recurring access duration should derive from the product cycle.
- Keep access expiration/revocation logic in `AccessService` or the relevant payment workflow, not in controllers.

## Notifications, Socket, Push, And Email

- `NotificationService` coordinates socket, push, and email fanout.
- Use dedicated notification jobs for provider delivery.
- Do not let optional notification provider failure roll back completed core domain work unless the feature explicitly requires it.
- Keep OneSignal/template identifiers in provider/service layers, not controllers.

## AI And Chat

- AI chat work is queued and durable. Do not turn long-running provider calls into synchronous controller work.
- Preserve room/message state transitions: queued, processing, completed, failed.
- Keep provider calls behind `AiService::Client`.
- Keep completion/failure notifications after DB state is committed.
- Maintain per-room concurrency/idempotency behavior.

## Storage And Assets

- Keep provider-specific upload/delete/list behavior behind `StorageService::Client`.
- Do not expose arbitrary local filesystem paths through API responses.
- Queue remote deletion after local DB changes where current behavior does so.
- Preserve category/media metadata and ownership fields.

## Localization And Messages

- Use existing `MessageService` modules for response messages.
- Add message keys in the appropriate domain message service when introducing new reusable messages.
- Preserve English/Myanmar localization behavior when endpoints are client-facing.

## OpenAPI And Client Contract

- Update `spec/openapi/**` when request/response fields, endpoint behavior, or schemas change.
- Keep serializers, specs, and OpenAPI docs aligned.
- If the frontend/mobile client depends on a field, do not remove or rename it without updating the client and documenting the contract change.

## Tests And Validation

Use Docker for backend specs because the project runtime is Ruby `4.0.4` and the host Ruby may not match.

Run focused specs for the area changed, for example:

```bash
docker compose -f docker-compose.dev.yaml run --rm api bundle exec rspec spec/services/payment_service/stripe_spec.rb
```

For broader validation, prefer:

```bash
docker compose -f docker-compose.dev.yaml run --rm api bundle exec rspec
```

Also run syntax checks for edited Ruby files when useful:

```bash
ruby -c path/to/file.rb
```

Before declaring backend work done, report the exact commands run and whether they passed or failed. If a command fails because of environment/tooling, report the real blocker.

Generated files such as `spec/examples.txt` may change after specs. Do not include generated bookkeeping diffs unless intentionally updating them.

## Change Discipline

- Keep changes scoped to the requested domain.
- Do not refactor unrelated files while fixing a bug.
- Do not revert user changes.
- Do not hard-delete data lifecycle behavior, provider integration, routes, serializers, or specs without explicit approval.
- Add the smallest useful tests for changed behavior.
- Prefer existing local patterns over new abstractions.
- Use explicit types/classes/modules and clear names.
- Keep comments sparse and useful.

## Before Reporting Done

Include:

- Existing backend flow inspected
- Files changed
- Any API/OpenAPI changes
- Tests/commands run with outcomes
- Known unrelated failures or environment blockers
- Remaining risk, if any

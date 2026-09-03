> [!IMPORTANT]
>
> ### 🏛️ The Foundation Creed & Supreme Motivation
>
> **"Clarity before cleverness. Precision before haste. Simplicity without weakness. Strength without spectacle."**
>
> 📜 **Constitutional Mandate**: Non-negotiable architectural laws and engineering standards for all human engineers and autonomous AI agents on **Rexone Core** (`rexone-core`). Zero exceptions!!!
>
> This application is built upon the **Rexone Ecosystem** (`rex-9`). These are immutable **Rexone Laws and Protocols** to be strictly observed and enforced without any exception across all human engineers and autonomous AI agents. Developers building on top of this foundation are warmly encouraged to preserve ecosystem credit to support the project.

> > _"If you don't follow These LAWS, u're gay."_
> >
> > — _Newton'z Law_

---

## 🗂️ 1. Constants & Enums Law

### 1.1 Zero Loose String Literals or Magic Numbers

- **Rule**: Every status string, provider, platform, role, channel, audience type, asset type/format, and notification type MUST be a frozen string constant in `app/constants/`.
- Never use raw strings like `"active"`, `"canceled"`, `"web"`, `"mobile"`, `"user"`, `"google"` across controllers, models, services, jobs, serializers, or mailers.

### 1.2 Provider-Agnostic Storage Naming (`storage_key`)

- **Rule**: The universal storage identifier across all database columns, models, controllers, serializers, and `StorageService` implementations is `storage_key`.
- `public_id` is strictly isolated inside `StorageService::Cloudinary` as an internal provider argument and MUST NEVER leak into controllers, models, migrations, or serializers.

### 1.3 Explicit Base Units

- **Rule**: All unit-sensitive columns and variables must include explicit units in their names to avoid ambiguity:
  - `duration_secs` (integer seconds) on `assets`, `courses`, `lessons`, `sits`.
  - `size_bytes` (bigint bytes) on `assets`.
  - `unit_price_amount` (integer cents / smallest currency unit) on `payment_products`.
- Nulls are strictly preferred over "unknown" string fallbacks.

### 1.4 Three Concurrent Platform Sessions (`web`, `android`, `ios`)

- **Rule**: The platform taxonomy defines THREE isolated platform sessions: `AuthConstants::Platform::WEB` (`"web"`), `AuthConstants::Platform::ANDROID` (`"android"`), and `AuthConstants::Platform::IOS` (`"ios"`).
- A single user account can hold up to **3 active sessions concurrently** (one on Web, one on Android, and one on iOS).
- Logging in or replacing a session on Android will NOT revoke or invalidate an active session on iOS or Web, and vice versa. Each platform maintains its own isolated session key: `active_session:user:<user_id>:<platform>`.

---

## 🖼️ 2. Distributed Centralized Assets Law

### 2.1 Zero URL Columns on Domain Tables

- **Rule**: NEVER add `avatar_url`, `image_url`, `video_url`, or specific media URL columns into the `users` table or any domain resource tables (`products`, `courses`, etc.).
- ALL media is managed through the distributed centralized `assets` table:
  - Polymorphic link: Rails standard `assetable_type` (e.g. `"User"`) and `assetable_id` (UUID) via `belongs_to :assetable, polymorphic: true, optional: true`.
  - Metadata: `storage_key`, `type` (`AssetConstants::AssetType::*`), `format` (`AssetConstants::AssetFormat::*`), `source` (`AssetConstants::AssetSource::*`), `size_bytes`, `duration_secs`, `extension`.
- Owning models declare `has_many :assets, as: :assetable`. Setting `asset.assetable = user` automatically populates `assetable_type = "User"` and `assetable_id = user.id` via Rails standard polymorphic behavior.

### 2.2 Dynamic User Avatar Resolution

- The `User` model resolves avatars via `User#get_profile_pic_url`, querying `assets.where(type: AssetConstants::AssetType::AVATAR).order(Arel.sql("CASE WHEN source = 'upload' THEN 1 ELSE 2 END"), created_at: :desc).first&.url`.

---

## 🔐 3. Authentication, Authorization & RBAC Law

### 3.1 Authentication Boundary (`Auth::*` vs `V1::*`)

- **`Auth::*` Namespace**: Authentication only (Sign In, Sign Up, Passcode, SSO, Confirmations, Password Reset). No IAM authorization required.
- **`V1::*` Namespace**: All endpoints are protected by `authenticate_user!` and strictly authorized via IAM permissions.

### 3.2 Strict CRUD-Prefixed Controller Action Naming

- Authorization evaluates the **Resource** (controller name) and **Action** (`create`, `read`, `update`, `delete`).
- Custom controller actions MUST follow standardized CRUD prefixes or authorization resolution will fail:
  - **Create**: `create_*` (or standard `create`) $\rightarrow$ maps to `"create"` action
  - **Read**: `read_*`, `index`, `show` $\rightarrow$ maps to `"read"` action
  - **Update**: `update_*` (or standard `update`) $\rightarrow$ maps to `"update"` action
  - **Delete**: `destroy_*` (or standard `destroy`) $\rightarrow$ maps to `"delete"` action

### 3.3 Role Hierarchy & Administration Access (`/v1/admin/`)

The RBAC system defines a strict three-tier hierarchy for administration:

1. **`super_admin` (Full System Authority)**:
   - Complete, unrestricted access across all resources, endpoints, users, and IAM governance.
2. **`admin` (Standard Administrator)**:
   - Full operational access across all domain resources (`feedbacks`, `payments`, `ai`, `assets`, `logs`, `notifications`).
   - **Strict Restriction**: Restricted from managing `users` and `iam` (roles, permissions, role assignments).
3. **Partial Admin (`*_admin` Suffix Naming Law)**:
   - Designed for scoped administrative access where a user has the default `user` role plus one or more specific `*_admin` roles (e.g. `feedback_admin`, `payment_admin`, `ai_admin`, `content_admin`).
   - **Creation Law**: When creating partial admin roles, always use the `_admin` suffix in the role name (e.g. `feedback_admin`). Any role whose name contains `admin` is treated as an admin role.
   - **Access Scope & Permission Provenance**:
     - **Admin Endpoints (`/v1/admin/*`)**: Can ONLY be accessed if the user holds an admin role containing `admin` in its name that explicitly grants the corresponding CRUD permission. Permissions from non-admin roles (such as the base `user` role) **cannot** be used to access `/v1/admin/*`.
     - **Non-Admin Endpoints (`/v1/*`)**: A user with `read_<resource>` (or other CRUD actions) in an admin role can read both `/v1/<resource>` and `/v1/admin/<resource>`. A user with permissions only in a non-admin role can only access `/v1/<resource>`.
   - In frontend clients (Web), partial admins dynamically only see the admin sidebar navigation items corresponding to the `read_<resource>` permissions of their assigned `*_admin` roles.
   - **Single-Request IAM Introspection**: `GET /v1/users/current/iam` returns explicit `is_admin`, `is_super_admin`, `roles`, `admin_roles`, `non_admin_roles`, `permissions`, `admin_permissions`, and `non_admin_permissions` so frontend clients can immediately evaluate UI controls and sidebar items without secondary API calls.

### 3.4 Rails Internal Dashboards vs. Client Admin Portal Boundary

- **Rails Internal Dashboards (`/admin`, `/red`, `/solid_queue`, `/pulse`)**:
  - Reserved **strictly for Super Admins** (`super_admin`) for low-level system infrastructure, raw database inspection, job worker health, cache inspect, and server profiling.
- **Client Admin Portal (`/v1/admin/*` and Web `/admin/*`)**:
  - The primary business, operational, and customer support portal for all authorized staff and sub-admins (`super_admin`, `admin`, and `*_admin` roles).
  - Business operations (user accounts, IAM role delegations, product catalogs, customer entitlements/accesses, support feedbacks, client error telemetry, notifications, chat moderation) MUST be completely manageable via `/v1/admin/*` so sub-admins never require raw database, console, or infrastructure dashboard access.

---

## 🏛️ 4. Architecture & Controller Law (Strict MCS Pattern)

### 4.1 Business Logic (Server-Business Logic) Authority

- **Server-Business Logic as Single Source of Truth**: ALL primary application business logic (or **server-business logic**)—including data validations, authorization rules, access grants, pricing calculations, lifecycle state machines, rate limiting, transaction integrity, solid queues, and third-party orchestration—lives **exclusively in `rexone-core`**.
- **Zero Server-Business Logic Duplication in Clients**: Client applications (`rexone-web`, `rexone_mobile`) MUST NEVER replicate, re-calculate, or duplicate server-business logic. Client applications handle strictly **client-business logic** (frontend state management, device orchestration, and UI presentation).

### 4.2 Strict 3-Tier MCS Separation of Concerns

```
Model Layer (app/models/)
       │  (ActiveRecord entities, relationships, validations, scopes, DB constraints)
Controller Layer (app/controllers/)
       ↓  (Pure HTTP gateways: parses params, evaluates auth/IAM, invokes services)
Service Layer (app/services/)
       ↓  (Encapsulates all server-business logic, external SDKs, third-party gateways)
```

- **Models (`app/models/`)**:
  - Encapsulate data integrity, ActiveRecord associations, scopes, and database constraints.
  - Zero external HTTP or provider SDK calls in models.
- **Controllers (`app/controllers/`)**:
  - **Pure HTTP Gateway (Zero Server-Business Logic in Controllers)**:
    - Controllers strictly parse HTTP inputs, enforce authentication/authorization, permit specific parameters, delegate execution to `app/services/`, and render standardized JSON envelopes.
    - NEVER use loose fallback parameter hashes (e.g. `params[:type] || params[:category]`). Only explicitly permitted parameters are allowed.
- **Services (`app/services/`)**:
  - Shared domain services stored under root `app/services/` (e.g. `notification_service.rb`, `access_service.rb`, `google_auth_service.rb`) and nested domain namespaces (`payment_service/`, `ai_service/`, `storage_service/`, `push_noti_service/`, `socket_service/`, `email_service/`).
  - Services are used by any necessary controller or background job.

### 4.2 Mandatory Standardized JSON:API Envelope

- All responses must use `render_json_response`:
  ```json
  {
    "status": {
      "code": 200,
      "success": true,
      "message": "Localized message",
      "error": null
    },
    "data": { ... },
    "meta": {
      "pagination": { ... }
    }
  }
  ```

### 4.3 Mandatory Universal Pagy Pagination on ALL Collection Endpoints

- **Universal Pagy Protocol**: ALL list and index endpoints MUST use `Pagy` offset pagination (`pagy, records = pagy(collection)` via `PagyHelper`).
- **Default Full Collection (Zero Query Params)**: When the client requests a collection without `page` or `limit` parameters, `PagyHelper` automatically returns ALL records in a single page wrapped in standard `pagy` metadata (`current_page: 1`, `total_pages: 1`, `total_count: N`, `limit: total_count`).
- **Prohibition of "all" Flags & Branching**: Controllers MUST NEVER implement custom `if params[:limit] == "all"` branching or return unpaginated serializers without `pagy`. Clients NEVER pass `limit: "all"` or arbitrary string flags; omitting `page` and `limit` fetches the full collection cleanly and uniformly through `pagy`.
- **Zero Unpaginated Collections**: Never return unbounded database arrays or raw unpaginated collections.

---

## ⚙️ 5. Service Layer & Third-Party Boundary Law

### 5.1 All Business Workflows in `app/services/`

- Every domain workflow (AI chat processing, stripe checkout/webhooks, email delivery, media upload, IAM verification) lives in a dedicated service under `app/services/`.

### 5.2 Provider Isolation

- Third-party SDK integrations (Stripe, DeepSeek, Cloudinary, OneSignal) MUST be encapsulated behind generic service client boundaries:
  - `StorageService::Client` $\rightarrow$ `StorageService::Cloudinary` / `StorageService::Local`
  - `PaymentService::Client` $\rightarrow$ `PaymentService::Stripe`
  - `AiService::Client` $\rightarrow$ `AiService::DeepSeek`
  - `EmailService::Client` $\rightarrow$ `EmailService::OneSignal`
  - `PushNotiService::Client` $\rightarrow$ `PushNotiService::OneSignal`
  - `SocketService::Client` $\rightarrow$ `SocketService::ActionCable`

### 5.3 Mandatory Client Gateway & Base Contract Law

- **Rule**: ALL domain calls from models, controllers, and jobs MUST route through `*Service::Client` (e.g. `PaymentService::Client.create_customer`, `PaymentService::Client.create_checkout_session`, `AiService::Client.chat`). Direct invocation of concrete provider classes (e.g. `PaymentService::Stripe.*`, `AiService::DeepSeek.*`) is strictly forbidden across the codebase.
- **Rule**: Every concrete provider class MUST inherit from its domain `*Service::Base` (e.g. `PaymentService::Stripe < PaymentService::Base`) and implement all contract methods. `*Service::Client` MUST declare explicit class-level delegations to `:provider` for all base contract methods.

---

## 🔐 6. RBAC & IAM Authorization Law

### 6.1 Three-Tier Administrative Hierarchy

1. **`super_admin`**: Full authority across all operational, user governance, and IAM resource domains.
2. **`admin`**: Full operational authority (`feedbacks`, `payments`, `ai`, `logs`, `notifications`). Excluded from `users` and `iam`.
3. **Partial Admin (`*_admin` Suffix)**: Scoped authority over specific domain capabilities (e.g. `notification_admin`, `product_admin`, `chat_admin`, `log_admin`, `feedback_admin`).

### 6.2 Strict Non-Admin Role Isolation & Scoping Law

- **Non-Admin Portal Isolation**: Users holding ONLY non-admin roles (`user`, `member`, `subscriber`) have ZERO access to administrative endpoints or portal capabilities.
- **Role Scoping / Partitioning**: When evaluating administrative permissions, capabilities are scoped STRICTLY to resources covered by the user's active **admin roles** (`super_admin`, `admin`, `*_admin`). Permissions granted under base/non-admin roles (`user`) are ignored and never leak into administrative workflows.
- **Granular CUD Action Enforcement**:
  - `create`: Gated by `user.can?(:create, resource)`.
  - `update` / `edit`: Gated by `user.can?(:update, resource)`.
  - `discard` / `undiscard` / `destroy`: Gated by `user.can?(:delete, resource)`.
  - `read` / `index` / `show`: Gated by `user.can?(:read, resource)`.

---

## 🗄️ 7. Models, Database & Migrations Law

- **UUID Primary Keys**: All tables use `id: :uuid, default: -> { "gen_random_uuid()" }`.
- **Soft Deletion & Lifecycle Hierarchy**:
  - `discard` (Soft Delete): Stamps `discarded_at` timestamp. Invoked from the active view to move a record to the Recycle Bin.
  - `undiscard` (Restore in UI): Clears `discarded_at` to `nil`. In code, all method names, controller actions, routes, and services MUST strictly use `undiscard` (e.g. `put/post :undiscard`, `def undiscard`). "Restore" exists solely as the user-facing translated string literal.
  - `destroy` (Hard Delete): Permanently purges and deletes the record. Strictly restricted to the Recycle Bin for destroyable resources (e.g. chat messages, chat rooms).
  - **Non-Destroyable Resources**: Users, Products, Roles, and Permissions are strictly soft-deleted (`discard`) and restored (`undiscard`). They cannot be destroyed.
- **HTTP Methods & Routing Law**:
  - `PATCH` method is forbidden. Record updates use `PUT`. State transitions and lifecycle actions use `PUT` or `POST`.
- **Audit Trails**: Models with audit requirements include `Audited` concern (`created_by_id`, `updated_by_id`, `discarded_by_id`).
- **Timestamps**: All tables include `created_at` and `updated_at`.

---

## ⚡ 7. Background Jobs (Solid Queue)

- **Rule**: All heavy operations (email delivery, AI token generation, payment webhook reconciliations, storage deletions) MUST be queued via `ActiveJob` on `SolidQueue`.
- Dedicated queues:
  - `:default` — General maintenance & error logging
  - `:notifications` — Sockets, push notifications, emails
  - `:payments` — Stripe events and webhook processing
  - `:ai` — Asynchronous LLM generation and chat processing

---

## 🌍 8. Localization Law

- All user-facing strings and error messages MUST be defined in `config/locales/` (`en.yml`, `es.yml`, `my.yml`) and accessed via `MessageService::*` catalogs.
- `ApplicationController#switch_locale` automatically inspects `X-Locale` or `Accept-Language` headers and wraps requests in `I18n.with_locale`.

---

## 🧪 9. Testing & API Documentation Law

- **100% Passing Tests**: Full RSpec suite (`bundle exec rspec`) must pass with 0 failures before any commit.
- **OpenAPI / Swagger Sync**: OpenAPI definitions in `spec/openapi/` and generated docs (`swagger/v1/swagger.yaml`) must be updated and kept in sync with every API change.

---

## ⏰ 10. UTC Transport & Client-Side Local Timezone Law

- **Rule**: The backend operates strictly in UTC:
  - The database stores all timestamps in UTC.
  - The API receives all timestamp filters (`start_date`, `end_date`) exclusively as UTC ISO 8601 strings.
  - The API outputs all timestamps, time-series points, and records in UTC.
  - The backend NEVER accepts client timezones (`time_zone` params or headers) and NEVER performs per-client timezone shifting.
- **Rule**: Frontends (Web and Mobile) are solely responsible for:
  - Converting user local time ranges into UTC ISO 8601 strings before sending them to the API.
  - Converting incoming UTC timestamps into the user's local browser or mobile device timezone for presentation.

---

## 📚 11. Documentation Synchronization Law

- **Rule**: After EVERY feature creation, modification, or bugfix:
  - **`README.md`** MUST be updated with newly added endpoints, dashboard routes, jobs, or configuration variables.
  - **`ECOSYSTEM.md`** MUST be updated if changes affect cross-platform feature parity, shared contracts, WebSocket events, or communication protocols between Core, Web, and Mobile.
  - **`LAW.md`** represents the non-negotiable constitutional framework; it should ONLY be modified when establishing, refining, or expanding fundamental architectural laws and engineering standards.

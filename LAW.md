> [!IMPORTANT]
> ### 🏛️ The Foundation Creed
> **"Clarity before cleverness. Precision before haste. Simplicity without weakness. Strength without spectacle."**
>
> This document defines the non-negotiable architectural laws and engineering standards for **Rexone Core** (`rexone-core` Rails API). Every developer, agent, and contributor must adhere strictly to these rules. Zero exceptions.

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
  - Polymorphic link: `resource_model` (e.g. `"user"`) and `resource_id` (UUID).
  - Metadata: `storage_key`, `type` (`AssetConstants::AssetType::*`), `format` (`AssetConstants::AssetFormat::*`), `source` (`AssetConstants::AssetSource::*`), `size_bytes`, `duration_secs`, `extension`.
- Setting polymorphic resources (e.g., `asset.resource = user`) automatically populates `resource_model = "user"` (`record.class.model_name.singular`) and `resource_id = user.id`.

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
- A user can only access `/v1/admin/` routes if their assigned role contains `"admin"` in its name.
- Admin access is strictly governed by IAM permissions:
  - `super_admin`: Full access across all administration resources.
  - `admin`: Full access EXCEPT for `users` and `iam` (user administration, role/permission management).
  - Custom roles: Access strictly granted based on their explicit IAM permissions.

---

## 🏛️ 4. Controller & API Envelope Law

### 4.1 Pure HTTP Gateway (Zero Business Logic in Controllers)
- **Rule**: Controllers strictly parse HTTP inputs, enforce authentication/authorization, permit specific parameters, delegate execution to `app/services/`, and render standardized JSON envelopes.
- **Rule**: NEVER use loose fallback parameter hashes (e.g. `params[:type] || params[:category]`). Only explicitly permitted parameters are allowed.

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

### 4.3 Mandatory Pagination on ALL Collection Endpoints
- **Rule**: ALL list/index endpoints MUST use `Pagy` offset pagination (`pagy(:offset, collection, limit: params[:limit])`).
- Never return unbounded database arrays or unpaginated collections.

---

## ⚙️ 5. Service Layer & Third-Party Boundary Law

### 5.1 All Business Workflows in `app/services/`
- Every domain workflow (AI chat processing, stripe checkout/webhooks, email delivery, media upload, IAM verification) lives in a dedicated service under `app/services/`.

### 5.2 Provider Isolation
- Third-party SDK integrations (Stripe, DeepSeek, Cloudinary, OneSignal) MUST be encapsulated behind generic service client boundaries:
  - `StorageService::Client` $\rightarrow$ `StorageService::Cloudinary` / `StorageService::Local`
  - `PaymentService::Client` $\rightarrow$ `PaymentService::Stripe`
  - `AiService::Client` $\rightarrow$ `AiService::DeepSeek`
  - `EmailService::Client` $\rightarrow` `EmailService::OneSignal`
  - `PushNotiService::Client` $\rightarrow$ `PushNotiService::OneSignal`
  - `SocketService::Client` $\rightarrow$ `SocketService::ActionCable`

---

## 🗄️ 6. Models, Database & Migrations Law

- **UUID Primary Keys**: All tables use `id: :uuid, default: -> { "gen_random_uuid()" }`.
- **Soft Deletion**: Entities supporting recovery use the `Discard` gem (`discarded_at`).
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

## 📚 10. Documentation Synchronization Law

- **Rule**: After EVERY feature creation, modification, or bugfix:
  - **`README.md`** MUST be updated with newly added endpoints, dashboard routes, jobs, or configuration variables.
  - **`ECOSYSTEM.md`** MUST be updated if changes affect cross-platform feature parity, shared contracts, WebSocket events, or communication protocols between Core, Web, and Mobile.
  - **`LAW.md`** represents the non-negotiable constitutional framework; it should ONLY be modified when establishing, refining, or expanding fundamental architectural laws and engineering standards.


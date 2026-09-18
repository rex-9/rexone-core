# RexOne Security Architecture & Zero-Leak Defense

This document outlines the sovereign security architecture, cryptographic safeguards, and defense-in-depth mechanisms engineered into RexOne to protect open-source downstream derivatives and enterprise deployments.

---

## 🏛️ 1. The Security Doctrine

In open-source software, security can never rely on obscurity (hoping an attacker doesn't know endpoint URLs or database tables). RexOne adheres strictly to **Kerckhoffs’s Principle**:

> *"A system should remain mathematically and architecturally secure even if the attacker has complete access to the public source code, schema, and API contracts."*

RexOne enforces zero-default-secret policies, strict rate limiting, zero-trust network boundaries, and pre-commit secret scanning to ensure products built on RexOne cannot accidentally deploy with compromised credentials or vulnerable surfaces.

---

## 🛡️ 2. Production Security Boot Guard

Located in [`config/initializers/security_boot_guard.rb`](../config/initializers/security_boot_guard.rb), the Boot Guard acts as a circuit breaker during server startup:

### A. Production Enforcement (Fatal Abort)
When running in `production` (or when `ENFORCE_BOOT_GUARD=true`), RexOne audits all critical cryptographic keys at boot:
- **`RAILS_SECRET_KEY_BASE`**: Must not be blank, shorter than 32 characters, or equal to `"secret-key-base"`, `"change-me"`.
- **`RAILS_JWT_SECRET_KEY`**: Must not be blank, shorter than 16 characters, or equal to `"rexone"`, `"secret"`.
- **`PG_PASSWORD`**: Must not be blank or equal to default database passwords (`"password"`, `"postgres"`, `"admin"`).
- **`S3_ADMIN_TOKEN`**: Must not be blank or equal to `"rexone_garage_admin_token_secret_key_12345"`.

If any critical key is insecure, **RexOne aborts immediately** with a prominent alert banner:
```text
======================================================================
  🚨 FATAL SECURITY BOOT GUARD VIOLATION (Production Aborted)
======================================================================
RexOne refused to boot because critical production secrets are insecure:
  ❌ RAILS_JWT_SECRET_KEY: matches insecure default placeholder 'rexone'
     Description: JWT authentication signature key
======================================================================
```

### B. Development Environment Diagnostics
In `development`, instead of halting execution, Boot Guard prints an actionable diagnostic report alerting developers to missing or placeholder integration keys, explicitly stating which feature is impacted:
- **`BREVO_API_KEY`**: User account confirmation codes and password reset emails will not be sent.
- **`STRIPE_SECRET_KEY`**: Checkout sessions, payment intents, and customer subscriptions will fail.
- **`DEEPSEEK_API_KEY` / `GEMINI_API_KEY`**: AI chat completions and LLM features will fail.
- **`ONE_SIGNAL_API_KEY`**: Push notifications will not be delivered.
- **`AZURE_SPEECH_KEY`**: Real-time WebSocket speech-to-text is disabled (Nova HTTP STT remains active).

### C. Production Secret Generation CLI
To generate high-entropy 64-byte and 32-byte production secrets:
```bash
./scripts/generate_secrets.sh
```

---

## 🌐 3. Zero-Trust Localhost & CORS Hardening

Located in [`config/initializers/cors.rb`](../config/initializers/cors.rb) and [`config/environments/production.rb`](../config/environments/production.rb):

1. **Localhost Isolation in Remote Tiers**:
   - `http://localhost(:\d+)?` and `http://127.0.0.1(:\d+)?` are **strictly blocked** in production and UAT CORS policies and Action Cable allowed request origins.
   - Prevents cross-origin localhost attacks where malicious scripts running on an admin's local browser target authenticated remote sessions.
   - Can only be enabled in production if explicitly opted into via `CORS_ALLOW_LOCALHOST=true`.
2. **Zero-Hardcoded Product Domains**:
   - All product origins are derived dynamically via `PRODUCT_DOMAIN` (e.g. `PRODUCT_DOMAIN=rexone.me` or `acme.com`).
   - Automatically supports `http`, `https`, `www.`, `uat.`, `dev.`, and all nested subdomains across any TLD (`.com`, `.io`, `.ai`, `.app`, `.org`, etc.).
3. **Demo Showcase Parity**:
   - Wildcard support for the live demo tier (`rex9.me` and `rexone.rex9.me`).

---

## 🚦 4. Authentication Surface Rate Limiting (`Rack::Attack`)

Located in [`config/initializers/rack_attack.rb`](../config/initializers/rack_attack.rb):

All public identity endpoints are protected by hardware-level IP throttles:

| Endpoint | Method | Rate Limit | Primary Attack Mitigation |
| :--- | :--- | :--- | :--- |
| **`/peek`** | `GET` | **12 req / 1 min** (1 every 5s) | **User Enumeration & Account Scraping**: Stops automated bots from probing the database for registered email addresses. |
| **`/signin*`** | `POST` | **10 attempts / 5 mins** | **Credential Stuffing**: Prevents brute-forcing passwords or authentication tokens. |
| **`/signup`** | `POST` | **10 attempts / 5 mins** | **Bot Account Flooding**: Prevents automated spam registrations. |
| **`/confirmation/send_code`** | `POST` | **10 requests / 5 mins** | **Transactional Email Bombing**: Prevents draining email quotas (Brevo/SES). |
| **`/password/forgot`** | `POST` | **10 requests / 5 mins** | **Reset Flooding & Harassment**: Prevents repeated reset email delivery. |
| **General Auth** | `*` | **60 req / 1 min** | **Baseline DoS Shielding**: Absorbs general authentication traffic spikes. |

When throttled, the API returns HTTP 429 (`Too Many Requests`) with a standardized JSON envelope and `Retry-After` header.

---

## 🔒 5. Pre-Commit Secret Scanner & Git Hook Automation

Located in [`scripts/check_secrets.sh`](../scripts/check_secrets.sh) and [`scripts/install_pre_commit.sh`](../scripts/install_pre_commit.sh):

Every developer working on RexOne installs the local pre-commit guardrail:
```bash
./scripts/install_pre_commit.sh
```

### What It Blocks Before Every Commit:
1. **Uncommitted `.env` Files**:
   - Detects any staged `.env`, `.env.local`, `.env.prod`, or `.env.uat` file and immediately blocks the commit.
   - Only `.env.example` is permitted in source control.
2. **High-Risk Cryptographic & Cloud Secrets**:
   - Private Keys (`-----BEGIN RSA/OPENSSH/EC PRIVATE KEY-----`)
   - AWS Access Keys (`AKIA[0-9A-Z]{16}`)
   - Stripe Live Secret Keys (`sk_live_[0-9a-zA-Z]{24,}`)
   - GitHub Personal Access Tokens (`ghp_[0-9a-zA-Z]{36}`)
   - Google API Keys (`AIzaSy[0-9A-Za-z_-]{33}`)
3. **Locale & MessageService Integrity**:
   - Validates that all translation keys have 1-to-1 parity between English and Burmese before allowing commits.

---

## 📱 6. Mobile CI/CD Secret Isolation

In [`rexone_mobile`](https://github.com/rex-9/rexone-mobile):
- Mobile applications declare `.env.dev`, `.env.uat`, and `.env.prod` in `.gitignore`.
- Cloud builds on GitHub Actions ([`.github/workflows/build_android.yaml`](https://github.com/rex-9/rexone-mobile/blob/main/.github/workflows/build_android.yaml)) inject `.env.uat` and `.env.prod` dynamically from **GitHub Repository Secrets** (`ENV_UAT` and `ENV_PROD`).
- Build artifacts (`.apk`) are uploaded to GitHub Actions Artifacts and attached to tagged GitHub Releases (`vX.X.X-uat+B` or `vX.X.X+B`).

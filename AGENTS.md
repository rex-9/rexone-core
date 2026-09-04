# Autonomous AI Agent & Development Guidelines (`rexone-core`)

## 🏛️ Immutable Project Laws & Constitutional Guidelines

1. **Supreme Primacy of the Law (`LAW.md`)**:
   - `LAW.md` is the non-negotiable constitutional framework and takes **ABSOLUTE FIRST PRIORITY** over existing code, implementation conveniences, or external assumptions.
   - **NEVER modify, bend, or "fix" `LAW.md` to accommodate non-compliant code.**
   - If existing code violates or deviates from `LAW.md`, **THE CODE IS WRONG — FIX THE CODE.**
   - `LAW.md` may ONLY be adjusted when the project creator (Rex) explicitly decrees a constitutional law change.

2. **Omnipresent Documentation Synchronization (`SCHEMA.md`, `README.md`, `ECOSYSTEM.md`)**:
   - **`SCHEMA.md`**: MUST be updated synchronously EVERY TIME the database schema or `ApplicationRecord` models are created, migrated, altered, or updated (strictly core business tables; never background telemetry).
   - **`README.md`**: MUST be updated synchronously whenever features, routes, endpoints, background queues/jobs, CLI scripts, or configuration parameters are added, modified, or retired.
   - **`ECOSYSTEM.md`**: MUST be updated synchronously whenever changes affect cross-platform contracts, WebSocket event catalogs, shared data structures, or communication protocols between Core, Web, and Mobile.
   - **Same Turn Synchronization**: Documentation is NOT an afterthought; update documentation files in the exact same turn as code changes.

3. **Storage Provider Standard**:
   - Default `STORAGE_PROVIDER` is `garage` (self-hosted S3-compatible storage on port 3100).
   - Universal storage key identifier is `storage_key`. Never use provider-specific terms like `public_id` in domain tables or controllers.

4. **Strict Git Safety Protocol**:
   - NEVER propose, execute, or ask about `git add`, `git commit`, or `git push`.

5. **Environment File & Secret Isolation Protocol**:
   - NEVER read, view, parse, or directly modify local gitignored `.env` files.
   - Only `.env.example` may be inspected, modified, or maintained.
   - Always provide explicit, clean copy-paste snippets for developers to apply to their local `.env` manually.
   - Do NOT run out-of-band scripts or commands that mutate local state without leaving traces in git source control.

# Google Summer of Code (GSoC) — Project Ideas Catalog

Welcome to the **RexOne Ecosystem Google Summer of Code (GSoC)** project ideas catalog! 🌍

RexOne is a unified, discipline-driven product engineering foundation spanning **Rails 8 API (`rexone-core`)**, **React 19 Web (`rexone-web`)**, and **Flutter Mobile (`rexone_mobile`)**. 

All GSoC projects are bounded, production-grade engineering initiatives designed to expand the ecosystem's capabilities while respecting our architectural constitution ([`LAW.md`](../LAW.md)) and **Discipline-Driven Development (DDD)**.

---

## 📋 General Guidelines for GSoC Candidates

- **Communication**: Join the conversation on [GitHub Discussions](https://github.com/rex-9/rexone-core/discussions).
- **Proposals**: All proposals must demonstrate an understanding of RexOne's tri-platform contracts, `LAW.md`, and local pre-commit verification workflows.
- **AI Policy**: In alignment with our [`AI_CONTRIBUTION_POLICY.md`](AI_CONTRIBUTION_POLICY.md), candidates may use AI coding assistants to accelerate development, provided all code is verified, thoroughly tested, and architecturally compliant.

---

## 🚀 Project Ideas List

---

### Project 1: Adaptive HLS/CMAF Media Pipeline & Transcoding Daemon
- **Repository**: `rexone-core` / `rexone-web` / `rexone_mobile`
- **Expected Size**: ~350 hours (Large)
- **Difficulty**: Hard
- **Skills Required**: Ruby on Rails 8, FFmpeg, HLS/DASH/CMAF, Docker, Background Workers (Solid Queue)
- **Potential Mentors**: Rex (`@rex-9`), Module Stewards

#### Description:
RexOne currently supports direct audio/video streaming with SRT subtitle synchronization and signed S3/Garage storage downloads. This project will introduce an enterprise-grade, self-hosted adaptive bitrate (ABR) transcoding daemon. When a video asset is uploaded to Garage S3, a background worker automatically segments it into multi-bitrate HLS (1080p, 720p, 480p, 360p) with CMAF low-latency support and master playlists.

#### Expected Outcomes:
1. Solid Queue background worker orchestrating containerized FFmpeg for HLS/CMAF packaging.
2. Direct integration with Garage S3 storage buckets with signed segment authorization.
3. Native playback integration with Vidstack player in Web and `video_player` / `better_player` in Flutter.
4. Comprehensive automated test suite verifying edge-case handling for malformed containers and interrupted transcoding.

---

### Project 2: Cross-Platform Offline Sync & Vector-Clock Conflict Resolution
- **Repository**: `rexone_mobile` / `rexone-core`
- **Expected Size**: ~350 hours (Large)
- **Difficulty**: Hard
- **Skills Required**: Dart, Flutter, Drift (SQLite), Ruby on Rails 8, Distributed Systems, CRDTs / Vector Clocks
- **Potential Mentors**: Rex (`@rex-9`), Mobile Stewards

#### Description:
RexOne Mobile features an offline-first Drift SQLite database. This project aims to design and implement a bidirectional data synchronization engine with vector-clock conflict resolution. Users can create, update, and manage entities while offline; when connectivity is restored, mutations are batched, validated against server-side authorization policies, and merged deterministically without silent data loss.

#### Expected Outcomes:
1. Deterministic sync queue in Drift SQLite with retry, backoff, and state persistence.
2. Server-side idempotency endpoints in Rails 8 verifying mutation sequence numbers.
3. Visual sync status indicator and conflict-resolution UI in Flutter for unresolved simultaneous edits.
4. Stress-tested offline integration test suite verifying network partition recovery.

---

### Project 3: Automated `LAW.md` AST Compliance Linter (`rexone-lint`)
- **Repository**: `rexone-core` / Tooling
- **Expected Size**: ~175 hours (Medium)
- **Difficulty**: Medium
- **Skills Required**: Ruby (Parser / RuboCop AST), TypeScript (ESLint plugin / AST), Dart (Analyzer API)
- **Potential Mentors**: Rex (`@rex-9`)

#### Description:
RexOne is governed by `LAW.md` and `AGENTS.md`. Currently, architectural compliance is enforced via bash verification scripts and manual code review. This project will create a unified, multi-language static analysis CLI that inspects ASTs to detect architectural violations before code reaches code review:
- Forbidding provider-specific imports in domain models (e.g. AWS SDK in controllers).
- Enforcing deterministic parameter contracts (flagging loose option hashes or duplicate synonym keys).
- Detecting unlocalized UI strings and untested controller actions.

#### Expected Outcomes:
1. Custom RuboCop cops for Rails core rules.
2. Custom ESLint rules for React web architecture rules.
3. Dart Analyzer plugin for Flutter mobile rules.
4. A unified CLI tool (`./scripts/lint_laws.sh`) integrated into pre-commit hooks and GitHub Actions CI.

---

### Project 4: OpenSSF SLSA Level 3 Provenance & Supply-Chain Hardening
- **Repository**: All Repositories (`rexone-core`, `rexone-web`, `rexone_mobile`)
- **Expected Size**: ~175 hours (Medium)
- **Difficulty**: Medium
- **Skills Required**: GitHub Actions, Docker, Cosign / Sigstore, OpenSSF Scorecard, SLSA Framework
- **Potential Mentors**: Rex (`@rex-9`), Security Stewards

#### Description:
RexOne adheres to strict cryptographic security and zero-leak doctrine. This project will advance RexOne's security posture to achieve an **OpenSSF Scorecard score > 9.0** and **SLSA Level 3 build provenance**. The contributor will implement automated container signing with Sigstore/Cosign, software bill of materials (SBOM) generation via Syft/CycloneDX, automated vulnerability scanning via Trivy/OSV, and branch protection automation.

#### Expected Outcomes:
1. Automated GitHub Actions workflow generating verifiable SLSA Level 3 provenance for all Docker releases.
2. Cryptographically signed container images published with Cosign keys.
3. Continuous SBOM generation and dependency pinning (with hash validation).
4. Full audit and publication of RexOne's OpenSSF Scorecard report.

---

### Project 5: Cross-Platform Distributed Tracing & OpenTelemetry Correlation
- **Repository**: All Repositories (`rexone-core`, `rexone-web`, `rexone_mobile`)
- **Expected Size**: ~175 hours (Medium)
- **Difficulty**: Medium
- **Skills Required**: OpenTelemetry, Rails 8, React 19, Flutter, Grafana / Jaeger
- **Potential Mentors**: Rex (`@rex-9`)

#### Description:
Building on RexOne's universal telemetry schema (`docs/SCHEMA.md`), this project will implement end-to-end distributed tracing across client requests. A trace originating from a button press on Flutter Mobile or React Web will propagate its `traceparent` context through API requests, WebSocket subscriptions, and Solid Queue background jobs, culminating in full waterfall visualization in Jaeger or Grafana Tempo.

#### Expected Outcomes:
1. OpenTelemetry instrumentation for Rails 8 API controllers, Action Cable, and Solid Queue.
2. Trace context injection in React Web `api.service.ts` and Flutter Mobile HTTP clients.
3. Docker Compose dev observability stack (Jaeger, Prometheus, Grafana).
4. Documentation and latency benchmarking guide in `docs/OBSERVABILITY.md`.

---

### Project 6: Interactive Developer CLI & Product Scaffolding Wizard (`rexone-cli`)
- **Repository**: Tooling
- **Expected Size**: ~90 hours (Small)
- **Difficulty**: Easy / Medium
- **Skills Required**: Shell / Node.js / Go / Rust, CLI UX, Inquirer, Git
- **Potential Mentors**: Rex (`@rex-9`)

#### Description:
Create a polished, interactive command-line interface (`rexone-cli` or `npx rexone`) that streamlines the developer onboarding journey. The CLI will guide new developers through cloning, environment initialization, Docker container bootstrapping, automated secret generation (`./scripts/generate_secrets.sh`), and interactive rebranding (`./scripts/rebrand.sh`) with live validation.

#### Expected Outcomes:
1. Interactive terminal UI with colorized diagnostics, dependency checkers (checking Docker, Ruby, Node, Flutter), and port conflict detection.
2. One-command setup: `rexone init my-product` automating brand configuration generation.
3. Pre-flight health checker running diagnostics against database, Redis/Cable, and Garage S3.
4. Comprehensive developer documentation and demonstration screencast.

---

## 📬 Submitting Your Proposal

Interested contributors should:
1. Review [`CONTRIBUTING.md`](../CONTRIBUTING.md), [`LAW.md`](../LAW.md), and [`AI_CONTRIBUTION_POLICY.md`](AI_CONTRIBUTION_POLICY.md).
2. Set up RexOne locally and submit a pull request resolving a [`good first issue`](https://github.com/rex-9/rexone-core/labels/good%20first%20issue).
3. Draft a proposal following the official GSoC application format and share it on GitHub Discussions for early maintainer feedback.

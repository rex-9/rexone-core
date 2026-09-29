# Contributing to the RexOne Ecosystem

First off, thank you for considering contributing to RexOne! 🚀

RexOne is a unified cross-platform product engineering foundation spanning **Rails 8 API (`rexone-core`)**, **React 19 Web (`rexone-web`)**, and **Flutter Mobile (`rexone_mobile`)**. 

Our engineering culture is governed by **Discipline-Driven Development (DDD)**:
> *"Start from One. Not from Zero." — Build software with rigorous architectural boundaries, deterministic contracts, verified tests, and zero unmaintainable "vibe-coding" debt.*

---

## 🏛️ 1. The Supreme Constitutional Law

Before writing any code, every contributor (human engineer or AI coding agent) must review:
1. **[`LAW.md`](LAW.md)**: The supreme architectural constitution governing data models, storage providers, parameter contracts, API routes, and code hygiene.
2. **[`AGENTS.md`](AGENTS.md)**: Development guidelines and strict operational guardrails.
3. **[`docs/AI_CONTRIBUTION_POLICY.md`](docs/AI_CONTRIBUTION_POLICY.md)**: Mandatory rules for AI-assisted code contributions.

> **Law U1 (Primacy of the Law)**: If existing code violates or deviates from `LAW.md`, the code is wrong — fix the code. `LAW.md` takes non-negotiable first priority.

---

## 🛠️ 2. Development Workflow

### A. Branching Strategy
- **`main`**: Production-ready, locked baseline releases.
- **`dev`**: Active integration branch. **All feature branches must branch off and merge back into `dev`.**
- **Feature Branches**: Use descriptive branch names:
  - `feat/adaptive-hls-streaming`
  - `fix/offline-drift-sync-conflict`
  - `docs/clarify-garage-s3-spec`

### B. Setting Up Your Environment
Follow the comprehensive guides for your targeted platform:
- **Core (Rails 8)**: Consult [`docs/QUICK_START.md`](docs/QUICK_START.md) and [`README.md`](README.md).
- **Web (React 19)**: Consult `rexone-web/README.md`.
- **Mobile (Flutter)**: Consult `rexone_mobile/README.md`.

### C. Pre-Commit Verification (Zero Regression)
Before submitting a pull request, run the automated verification scripts:

```bash
# In rexone-core:
./scripts/check_secrets.sh       # Verify no accidental .env or credentials are staged
bundle exec rubocop             # Ruby static analysis & style
bundle exec rspec               # Full backend test suite

# In rexone-web:
npm test                        # Vitest test suite
npm run check:architecture      # Zero-loose-code architecture compliance
npm run check:locales           # 100% key parity between en.json and my.json
npm run build                   # TypeScript & Vite build verification

# In rexone_mobile:
flutter analyze                 # Dart static analysis
flutter test                    # Flutter unit & widget tests
```

---

## 📝 3. Omnipresent Documentation Synchronization

Documentation in RexOne is never an afterthought. When submitting PRs that affect core tables, endpoints, or contracts:
- **`docs/SCHEMA.md`**: Must be updated synchronously whenever database tables, migrations, or `ApplicationRecord` models are touched.
- **`README.md`**: Must be updated synchronously whenever routes, background jobs, or configuration keys change.
- **`ECOSYSTEM.md`**: Must be updated synchronously whenever cross-platform contracts or WebSocket event catalogs change.

---

## 🤖 4. AI-Assisted Contributions

We welcome the responsible use of AI tools (Antigravity, Claude Code, Cursor, Copilot, ChatGPT). However, we strictly prohibit unverified "AI Slop" or unreviewed code dumps.

Every AI-assisted PR must:
1. Explicitly disclose the tools/models used in the PR description.
2. Certify that a human developer compiled, executed, and verified all tests locally.
3. Obey `LAW.md` (no alien syntax, no loose params, no dead code shims).

For details, read our [AI Contribution Policy (`docs/AI_CONTRIBUTION_POLICY.md`)](docs/AI_CONTRIBUTION_POLICY.md).

---

## 🎯 5. How to Get Started

Looking for an issue to tackle?
- **[`good first issue`](https://github.com/rex-9/rexone-core/labels/good%20first%20issue)**: Beginner-friendly issues to get familiar with our codebase and conventions.
- **[`help wanted`](https://github.com/rex-9/rexone-core/labels/help%20wanted)**: High-priority tasks where the community needs support.
- **[`gsoc`](https://github.com/rex-9/rexone-core/labels/gsoc)**: Substantial, bounded engineering projects for Google Summer of Code and open-source grants (see [`docs/GSOC_IDEAS.md`](docs/GSOC_IDEAS.md)).

---

## 💬 6. Questions & Community

- **Discussions & RFCs**: Use GitHub Discussions for proposals, architectural RFCs, and open dialogue.
- **Security Inquiries**: Follow the procedure outlined in [`SECURITY.md`](SECURITY.md).
- **Code of Conduct**: All participants are expected to adhere to our [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

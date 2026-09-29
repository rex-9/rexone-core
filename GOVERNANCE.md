# RexOne Ecosystem Governance Model

This document defines the decision-making framework, maintainer roles, constitutional amendment process, and long-term stewardship model for the RexOne Ecosystem.

---

## 🏛️ 1. Philosophy & Governance Structure

RexOne operates under a **Benevolent Dictator for Life (BDFL) / Lead Architect** governance model, supported by an active community of core maintainers, module stewards, and external contributors.

Our primary goal is to ensure architectural integrity, uncompromising software discipline, and long-term sustainability while fostering an open, inclusive, and transparent open-source community.

---

## 👥 2. Roles & Responsibilities

### A. Lead Architect & BDFL
- **Current Holder**: Rex (Htet Naing, `@rex-9`)
- **Authority**:
  - Ultimate authority over architectural strategy, constitutional law changes (`LAW.md`), and final dispute resolution.
  - Veto power over pull requests or RFCs that compromise the architectural constitution or violate **Discipline-Driven Development (DDD)**.
  - Appoints and promotes maintainers and module stewards.

### B. Core Maintainers
Core maintainers are trusted contributors with write and merge permissions across the repositories.
- **Responsibilities**:
  - Triage incoming issues and pull requests.
  - Review code for strict compliance with `LAW.md`, `AGENTS.md`, and `docs/AI_CONTRIBUTION_POLICY.md`.
  - Maintain automated CI pipelines and pre-commit verification gates.
  - Mentor new contributors, including Google Summer of Code (GSoC) participants.

### C. Module Stewards
Subject-matter experts responsible for specific subsystems:
- **Media & Streaming Steward**: Manages SRT, WebRTC, and HLS media pipelines.
- **Offline & Drift SQLite Steward**: Oversees mobile offline database architecture, drift migrations, and vector-clock sync.
- **Security & Infrastructure Steward**: Oversees Docker orchestration, Garage S3 integration, and secret scanners.

### D. Contributors
Anyone who submits code, documentation, bug reports, or architectural feedback. All contributors adhere to the [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) and [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## 📜 3. Decision-Making & Constitutional Amendments

### A. Everyday Decisions
Everyday bug fixes, test improvements, and non-breaking feature enhancements are reviewed and merged by any Core Maintainer through standard pull requests (requiring at least one approving review and clean CI passes).

### B. RFC (Request for Comments) Process
Major architectural additions, third-party provider integrations, or new platform services require an RFC:
1. Open a GitHub Discussion under the **RFC** category.
2. Clearly describe the problem, proposed solution, impact on Core/Web/Mobile contracts, and alternative approaches considered.
3. The community has a minimum of 7 calendar days to discuss and provide feedback.
4. Approval requires consensus from at least two Core Maintainers and formal sign-off from the Lead Architect.

### C. Constitutional Law Changes (`LAW.md`)
As decreed in Law U1:
> *"LAW.md is the non-negotiable constitutional framework and takes absolute first priority. LAW.md may ONLY be adjusted when the project creator (Rex) explicitly decrees a constitutional law change."*

No pull request modifying `LAW.md` may be merged without explicit sign-off by the Lead Architect.

---

## 💰 4. Financial Sponsorship & Institutional Grants

Financial contributions received through GitHub Sponsors, Open Collective, Google OSPO, grant foundations (e.g. Sovereign Tech Fund, NLnet), or corporate sponsors are held in trust and allocated exclusively for:
1. **Maintainer Stipends**: Compensating active open-source contributors and reviewers.
2. **Infrastructure & Hosting**: Covering CI runner compute, demo environments, domain registrations, and security auditing services.
3. **Student & Mentee Programs**: Funding student stipends and community hackathons (e.g. GSoC co-sponsorships).
4. **Independent Security Audits**: Commissioning third-party penetration testing and cryptographic reviews.

---

## 🔄 5. Becoming a Maintainer

Contributors who demonstrate consistent, high-quality involvement may be invited to join the maintainer team. Criteria include:
- Submitting multiple well-tested, compliant PRs adhering strictly to `LAW.md`.
- Actively assisting other community members with code reviews and issue triaging.
- Demonstrating sound engineering judgment and adherence to the Code of Conduct.

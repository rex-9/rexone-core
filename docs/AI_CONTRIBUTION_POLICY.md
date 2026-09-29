# RexOne AI-Assisted Contribution Policy

## 🏛️ The Anti-Vibe Coding Standard for the AI Era

In the modern software landscape, generative AI coding assistants (such as Google Antigravity, Claude Code, Cursor, GitHub Copilot, and ChatGPT) can dramatically accelerate engineering velocity. 

However, unconstrained AI usage frequently produces **"AI Slop"**: hallucinated APIs, superficial mock-only test suites, creeping technical debt, and architectural drift that burns maintainer attention and destroys project longevity.

RexOne exists to solve this dilemma. Through **Discipline-Driven Development (DDD)**, RexOne welcomes AI-assisted development **only under strict, machine-enforced architectural guardrails**.

---

## 📋 The Five Commandments of AI Contributions

Every pull request created with the assistance of AI tools must satisfy the following criteria:

### 1. Human Accountability
The human author submitting the pull request is **100% legally and technically accountable** for every character of code in the PR. 
- "The AI generated it that way" is **never an acceptable defense** for a bug, security flaw, or style violation.
- You must personally read, understand, and be prepared to defend and maintain every line of code you submit.

### 2. Strict Constitutional Conformance (`LAW.md` & `AGENTS.md`)
AI-generated code must obey the supreme project laws:
- **No Alien Syntax (Law U15)**: Reject dense one-liners, unreadable chained ternaries, or esoteric metaprogramming. Prefer clean, idiomatic control flow.
- **Zero Loose Code & Clean Contracts (Law U14)**: Parameter signatures must be unambiguous. No synonym keys or loose hash options.
- **Universal Provider Isolation (Law C1/W1/M1)**: No vendor-specific SDK imports leaking into business logic or UI controllers.

### 3. Verification Over Generation (Real Tests Required)
Any PR containing AI-generated logic must include corresponding automated tests:
- Tests must execute against real endpoints or test databases. Mock-only tests that merely repeat the implementation logic are rejected.
- You must certify that the full test suite passed locally before opening the PR:
  ```bash
  # Core:
  bundle exec rspec
  # Web:
  npm test && npm run check:architecture && npm run check:locales
  # Mobile:
  flutter analyze && flutter test
  ```

### 4. Omnipresent Documentation Synchronization
AI agents must not bypass documentation updates. If a pull request modifies database schemas, API routes, or cross-platform WebSocket contracts, the corresponding documentation must be updated in the exact same PR:
- `docs/SCHEMA.md`
- `README.md`
- `ECOSYSTEM.md`

### 5. Mandatory Transparency & PR Disclosure
When opening a pull request that utilized AI tools, you must include the **AI Disclosure Statement** in your PR description:

```markdown
### 🤖 AI Assistance Disclosure
- **Tool(s) Used**: [e.g., Google Antigravity, Claude Code, Cursor, Copilot, None]
- **Scope of Generation**: [e.g., Boilerplate scaffold, Test case suggestions, Refactoring, Full implementation]
- **Human Verification**: [X] I have read and understood every line of this pull request, executed all automated tests locally, and verified strict compliance with `LAW.md`.
```

---

## 🚫 Zero-Tolerance Rejections

A pull request will be **closed without review** if:
1. It is a raw, unverified dump of an LLM prompt output without tests.
2. It attempts to weaken, bypass, or rewrite `LAW.md` to accommodate non-compliant code.
3. It introduces unvetted external dependencies, security antipatterns, or phantom API calls.
4. It lacks the mandatory AI Assistance Disclosure.

---

## 💡 Recommended Agent Workflow

If you are pair-programming with an autonomous AI coding agent, equip your agent with [`AGENTS.md`](../AGENTS.md) and [`LAW.md`](../LAW.md) in its system instructions.

By forcing the agent to treat `LAW.md` as non-negotiable constitutional law, your AI pair programmer will generate pristine, production-grade code that sails through maintainer review.

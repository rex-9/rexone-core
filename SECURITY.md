# Security Policy & Vulnerability Disclosure

RexOne is committed to the highest standards of software security, cryptographic integrity, and supply-chain hygiene. We recognize the critical role that independent security researchers, community contributors, and automated tooling play in keeping open-source ecosystems safe.

---

## 🏛️ Supported Versions

We actively provide security patches, CVE remediations, and vulnerability fixes for the following versions:

| Version / Branch | Supported          | Security Maintenance Status |
| ---------------- | ------------------ | --------------------------- |
| `main` / `HEAD`  | :white_check_mark: | Active Security Updates     |
| `dev`            | :white_check_mark: | Pre-release / Nightly Scans |
| Legacy releases  | :x:                | Deprecated / Upgrade to main|

---

## 🚨 Reporting a Vulnerability

**Please DO NOT report security vulnerabilities via public GitHub issues, discussions, or social media.**

If you discover a security vulnerability, flaw, or potential exploit in RexOne (Core, Web, or Mobile), please disclose it responsibly via one of our confidential channels:

### 1. Preferred: GitHub Private Vulnerability Reporting
Submit a confidential advisory directly through GitHub:
- Navigate to the repository's **Security** tab.
- Click **Advisories** -> **Report a vulnerability**.
- Provide a detailed description, reproduction steps, and potential impact.

### 2. Direct Security Contact
If you are unable to use GitHub Advisories, email the security coordinator directly:
- **Email**: `rex9.tech@gmail.com`
- **Subject**: `[SECURITY VULNERABILITY] RexOne - <Brief Summary>`

---

## ⏱️ Response Timelines & SLA

Our maintainer team adheres to the following response timeline for security reports:

- **Initial Acknowledgment**: Within **48 hours** of receiving your report.
- **Triage & Assessment**: Within **72 hours**, confirming reproducibility and severity rating (CVSS).
- **Remediation & Patch Target**: 
  - **Critical / High Severity**: Patch developed, verified, and merged within **7 calendar days**.
  - **Medium / Low Severity**: Patch released with the next standard release cycle (within 30 days).
- **Public Disclosure**: Coordinated disclosure occurs only after an official patch and advisory are published.

---

## 🛡️ Safe Harbor for Security Researchers

RexOne welcomes responsible security research. We consider research activities to be conducted in good faith and authorized under the following conditions:
- You make a good-faith effort to avoid privacy violations, destruction of data, and interruption or degradation of running services.
- You do not exploit a security issue you discover beyond the minimum necessary proof-of-concept.
- You provide us reasonable time to remedy the vulnerability before publicly disclosing it.

We will not pursue legal action against researchers who adhere to this policy.

---

## 🔍 Architectural Security Reference

For an in-depth breakdown of RexOne's built-in defense-in-depth mechanisms, including:
- Production Security Boot Guard (`config/initializers/security_boot_guard.rb`)
- Zero-Trust Localhost CORS Hardening
- Universal S3/Garage Storage Provider Isolation
- Pre-Commit Cryptographic Secret Scanners

Please consult the comprehensive [RexOne Security Doctrine (`docs/SECURITY.md`)](docs/SECURITY.md).

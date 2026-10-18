---
name: secret-scrubber
description: Detects secrets, credentials, API keys, tokens and hard-coded passwords in code, configs, specs and examples. Masks them in any output meant for a log, a report or an external message. Use systematically before any audit output, any report generation, any trace that will leave the repository.
---

# secret-scrubber

## When to use

- Before producing any report that will leave the repository (audit, PR description, Slack/Jira message through MCP).
- When an agent is about to log or display a config file (`application.yml`, `.env`, files under `secrets/` or `prod-config/`).
- When the user pastes a payload that looks like a secret.

**Do not use** for: OWASP audit (use `owasp-reviewer`).

## Detected patterns

| Type | Pattern (regex/heuristic) |
|---|---|
| AWS Access Key | `AKIA[0-9A-Z]{16}` |
| AWS Secret | 40-char base64 + `aws_secret_access_key` context |
| JWT | `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` |
| Stripe live key | `sk_live_[0-9a-zA-Z]{24,}` |
| GitHub PAT | `ghp_[A-Za-z0-9]{36}` |
| Google API key | `AIza[0-9A-Za-z\-_]{35}` |
| Private key block | `-----BEGIN (RSA |EC |DSA |OPENSSH |)PRIVATE KEY-----` |
| Generic high-entropy | 32+ char string, base64/hex alphabet, Shannon entropy > 4.0 bits/char |
| Password in URL | `://[^/\s:]+:[^/\s@]+@` |
| `password=`, `secret=`, `token=`, `api[_-]?key=` assignments | context-based regex |

## Workflow

1. **Scan** the target content (string, file, glob).
2. **For each match**:
   - Log **locally**: type, path, line, **first 4 and last 4 characters** (never the secret in clear).
   - In any output meant to leave the repository, replace it with `«REDACTED:<TYPE>:<hash8>»`, where `hash8` is the first 8 characters of the secret's SHA-256 (deduplicates without revealing).
3. **If the secret is found in a committed file** (not only an in-memory buffer):
   - Severity: **CRITICAL**.
   - Recommend: (a) revoke the secret at the provider, (b) remove it from git history (`git filter-repo`), (c) move it to a vault.
4. **Always produce a summary**: `n secret(s) detected, m redacted in output, k require rotation`.

## False positives to avoid

- Documentation examples explicitly marked `EXAMPLE` / `dummy` / `fake`.
- UUIDs (high entropy, not a secret).
- Git hashes, build hashes, checksums.
- OpenAPI schemas that *describe* a token format (not an actual value).

## Output format

```
## Secret scan
Scope: <files or buffer>

Findings:
- HIGH  src/main/resources/application-prod.yml:14  AWS_ACCESS_KEY  AKIA...XYZW  → REDACTED in report
- CRITICAL  prod-config/db.yml:3  PRIVATE_KEY_BLOCK  -----BEGIN... → rotate immediately, remove from git history

Summary: 2 detected, 2 redacted in output, 1 requires rotation.
```

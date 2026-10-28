# deploy/secrets/ — REAL secrets live here, never in Git

This directory is git-ignored. It contains files that must never be committed,
logged or copied into artifacts (spec 11.3).

Expected files (created by the employer / server admin with `chmod 600`):

| File | Purpose | Consumed by |
|---|---|---|
| `ami` | Asterisk Manager Interface secret for `smi-control` (single line) | compose secret → `SMI_AMI_SECRET_FILE` |
| `apns.p8` | Apple Push Notification service token key (.p8, ES256) | iOS VoIP push |
| `fcm-service-account.json` | Firebase service account JSON (FCM HTTP v1) | Android push |

Rules:

1. No placeholder values in production: the scripts fail closed if
   `CHANGEME`/`REPLACE_ME` markers remain (see `scripts/lib/common.sh`).
2. Backups of these files belong in the employer's secret store — NOT in this
   repo, NOT in CI artifacts, NOT in chat.
3. The AMI secret is REQUIRED. Push credentials are optional until
   `docs/PREFLIGHT.md` items B2/B3 are resolved; while missing, push delivery
   reports failure explicitly (no fake success).
4. Rotate: `./smi device reset <ext> --credential-file <secure-path>` rotates
   extension secrets; AMI/APNs/FCM rotation follows the provider runbooks and a
   recorded decision.
5. If a secret was ever exposed in chat/Git/logs, treat it as compromised:
   revoke it first, then investigate.

Generate a strong AMI secret (example, on the server):

    openssl rand -base64 32 | tr -d '\n' > deploy/secrets/ami && chmod 600 deploy/secrets/ami

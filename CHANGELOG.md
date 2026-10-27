# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: SemVer.

## [0.1.0] — 2026-10-27 (initial scaffold — status: CodeReady partial, nothing DeviceValidated/Deployed/Published yet)

### Added
- Monorepo structure per PROJECT_SPEC section 12 (root contracts, docs, services/control, infra, deploy, contracts, apps/mobile, qa, scripts, CI).
- `toolchain.lock.json` with versions verified against official sources on 2026-10-27 (Flutter 3.47.8, Dart 3.13.7, .NET SDK 10.0.403, Asterisk 22.11.0 LTS with real SHA-256, Caddy 2.11.7, sip_ua 1.1.0, flutter_webrtc 1.6.3).
- Control service (.NET 10 Minimal API): sessions/login with PBKDF2 (600k) + opaque 256-bit tokens, device binding (409 on takeover), call state machine (Pending → Connecting → Connected → Ended, terminal `Ended`), transactional call-slot reservation, endpoints per spec section 7, ProblemDetails errors with `code`/`traceId`/`callId`, login rate limiting, health live/ready, extensions/device CLI (provisioning with atomic config render).
- Initial AMI client (loopback, ActionID matching, reconnect) + call coordinator (admission handshake, Setvar ordering, SMI_DIAL_ALLOWED on ready) — written against Asterisk 22 docs, **not yet validated against a live PBX (P2)**.
- APNs (token-based, HTTP/2, voip push type) and FCM HTTP v1 senders — **untested without real credentials (BLOCKED inputs)**.
- Asterisk 22 config templates (pjsip/http/manager/rtp/modules/extensions) implementing the SMI handshake algorithm of spec section 8.2 — **dialplan requires live validation (P2)**.
- Caddyfile exposing only `/api/v1`, `/health`, `/ws` over TLS.
- Docker Compose with exactly three persistent services (edge/pbx/control) using host networking and explicit `127.0.0.1` addresses.
- Contracts: hand-authored `openapi.json` (must be regenerated from code in P1), `push.schema.json`, `native-events.schema.json`.
- Flutter app core: `CallController` state machine, `SipAdapter`, `ControlApiClient`, `NativeCallBridge` (`smi.phone/native/v1`), native event queue (cap 64), secure credential store contract, minimal Persian/RTL UI (login, dialer, call), Persian/Arabic digit normalization.
- Native adapters as platform overlay: Android (FirebaseMessagingService, Core-Telecom phoneCall foreground service + CallStyle) and iOS (PushKit + CallKit provider) — **not yet built (needs `flutter create` + real toolchains)**.
- `./smi` CLI wrapper + scripts implementing the delivery-command contract; unimplemented commands fail with explicit NOT_IMPLEMENTED (exit 2) or BLOCKED (exit 3).
- CI (dotnet build/test, flutter analyze/test, contract validation, secret scan, Caddyfile validate) and gated release workflow (fail-closed on missing signing material).
- QA tracking: `qa/acceptance-tests.json` seeded T01–T60 as `NOT_RUN`, device test matrix template.

### Notes
- Repository/product name: `mini-voip-free` (per owner request). Wire-level SMI identifiers intentionally unchanged — see `docs/decisions/0001-project-naming.md`.

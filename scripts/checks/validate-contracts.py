#!/usr/bin/env python3
"""Contract validation (CI job `contracts`).

v0.1 scope: structural validation + required-path drift check against the
implemented API surface. Full OpenAPI generation from code + schema-conformance
tests for live traffic are P1 deliverables (see AGENTS.md roadmap).
Exit codes: 0 ok | 1 failure.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACTS = ROOT / "contracts"

REQUIRED_API_PATHS = {
    "/api/v1/sessions": {"post"},
    "/api/v1/sessions/current": {"delete"},
    "/api/v1/me": {"get"},
    "/api/v1/devices/current/push": {"put"},
    "/api/v1/calls/current": {"get"},
    "/api/v1/calls/{callId}": {"get"},
    "/api/v1/calls/{callId}/ready": {"post"},
    "/api/v1/calls/{callId}/accept": {"post"},
    "/api/v1/calls/{callId}/decline": {"post"},
    "/api/v1/calls/{callId}/end": {"post"},
    "/api/v1/ice-servers": {"get"},
    "/health/live": {"get"},
    "/health/ready": {"get"},
}

FORBIDDEN_PUBLIC_PATHS = (
    "/api/v1/send-push",
    "/api/v1/run-command",
    "/api/v1/setvar",
    "/api/v1/extensions",   # provisioning is CLI-only, never a public endpoint (spec 7.2)
)

REQUIRED_ERROR_CODES = {
    "INVALID_CREDENTIALS", "DEVICE_ALREADY_BOUND", "SESSION_EXPIRED",
    "CALL_NOT_FOUND", "CALL_ENDED", "CALL_EXPIRED", "STALE_DEVICE",
    "INVALID_TRANSITION", "PBX_NOT_READY", "RATE_LIMITED",
}


def load(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def main() -> int:
    failures = []

    openapi = load(CONTRACTS / "openapi.json")
    paths = openapi.get("paths", {})

    for path, methods in REQUIRED_API_PATHS.items():
        have = {m.lower() for m in paths.get(path, {})}
        missing = methods - have
        if missing:
            failures.append(f"openapi.json missing {sorted(missing)} on {path}")

    for path in paths:
        if any(path.startswith(p) for p in FORBIDDEN_PUBLIC_PATHS):
            failures.append(f"openapi.json exposes forbidden public path: {path}")

    codes = set(openapi.get("components", {}).get("schemas", {}).get("Problem", {})
                .get("properties", {}).get("code", {}).get("enum", []))
    missing_codes = REQUIRED_ERROR_CODES - codes
    if missing_codes:
        failures.append(f"openapi.json Problem.code missing: {sorted(missing_codes)}")

    push = load(CONTRACTS / "push.schema.json")
    for field in ("schemaVersion", "type", "callId", "deviceGeneration", "expiresAt"):
        if field not in push.get("required", []):
            failures.append(f"push.schema.json missing required field: {field}")

    native = load(CONTRACTS / "native-events.schema.json")
    ops = native.get("methodChannel", {}).get("operations", {})
    for op in ("configure", "getCapabilities", "getPushToken", "reportOutgoing",
               "updateCallState", "endCall", "setMuted", "setSpeaker",
               "getPendingEvents", "ackEvent"):
        if op not in ops:
            failures.append(f"native-events.schema.json missing operation: {op}")
    if native.get("methodChannel", {}).get("channel") != "smi.phone/native/v1":
        failures.append("native bridge channel name drifted from smi.phone/native/v1")

    if failures:
        for f in failures:
            print(f"FAIL {f}")
        return 1
    print("PASS contracts validated (openapi.json, push.schema.json, native-events.schema.json)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

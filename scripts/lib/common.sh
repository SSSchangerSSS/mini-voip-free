#!/usr/bin/env bash
# common.sh — shared helpers for smi wrapper scripts. Sourced, not executed.
# Exit codes: 0 ok | 1 execution error | 2 invalid input/prereq | 3 blocked

SMI_OK=0; SMI_ERR=1; SMI_INPUT=2; SMI_BLOCKED=3

log()  { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
ok()   { printf 'PASS %s\n' "$*"; }
warn() { printf 'WARN %s\n' "$*" >&2; }
fail() { printf 'FAIL %s\n' "$*" >&2; exit "$SMI_ERR"; }

fail_blocked() { printf 'BLOCKED %s\n' "$*" >&2; exit "$SMI_BLOCKED"; }
fail_input()   { printf 'INPUT_ERROR %s\n' "$*" >&2; exit "$SMI_INPUT"; }

not_implemented() { printf 'NOT_IMPLEMENTED %s\n' "$*" >&2; exit "$SMI_INPUT"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail_blocked "required command '$1' not found in PATH"
}

# Reject leftover placeholders in production-critical files (spec 11.3)
assert_no_placeholder() {
  local file="$1"
  [ -f "$file" ] || fail_input "file not found: $file"
  if grep -qE '(CHANGEME|REPLACE_ME|<[^>]*SECRET[^>]*>|__PLACEHOLDER__)' "$file"; then
    fail_blocked "$file still contains a placeholder; refusing to run in this mode (spec 11.3)"
  fi
}

# Read a secret from a file with restricted perms; never echo content.
read_secret_file() {
  local file="$1"
  [ -f "$file" ] || fail_blocked "secret file not found: $file"
  local perms
  perms="$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file")"
  [ "$perms" = "600" ] || warn "secret file $file has mode $perms (600 recommended)"
  # value is consumed by caller via $(read_secret_file ...); not printed
  tr -d '\r\n' < "$file"
}

# Machine-readable wrapper
json_out() { printf '%s\n' "$1"; }

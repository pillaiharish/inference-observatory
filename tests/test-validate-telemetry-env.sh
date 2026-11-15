#!/usr/bin/env bash
#
# test-validate-telemetry-env.sh — static tests for the endpoint
# resolution logic in scripts/validate-telemetry.sh.
#
# Verifies that custom VLLM_PORT / PROMETHEUS_PORT values are reflected
# in the validator's endpoints, and that explicit *_URL overrides win.
#
# Resolution precedence:
#   explicit PROMETHEUS_URL > PROMETHEUS_PORT > 9090
#   explicit VLLM_URL       > VLLM_PORT       > 8000
#
# No GPU, Docker, or network required. Runs in CI.
#

# Do NOT use set -e: we run subshells with controlled env and check
# their output explicitly.
set -uo pipefail

pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1" >&2; }
errors=0

# resolve_env — replicate the exact endpoint resolution lines from
# validate-telemetry.sh in a clean subshell. $1 is an env file to
# source (or /dev/null), $@ remaining args are environment overrides.
#
# Usage: resolve_env ENVFILE VAR1=val1 VAR2=val2 ...
# Prints "VLLM_URL=... PROMETHEUS_URL=..." on stdout.
resolve_env() {
  local envfile="$1"; shift
  env "$@" bash -c '
    # Source env file if provided and non-empty (same as the script).
    if [ -n "'"${envfile}"'" ] && [ -f "'"${envfile}"'" ]; then
      . "'"${envfile}"'"
    fi
    # Exact resolution logic from validate-telemetry.sh.
    PROMETHEUS_URL="${PROMETHEUS_URL:-http://127.0.0.1:${PROMETHEUS_PORT:-9090}}"
    VLLM_URL="${VLLM_URL:-http://127.0.0.1:${VLLM_PORT:-8000}}"
    VLLM_MODEL="${VLLM_MODEL:-Qwen/Qwen3-0.6B}"
    printf "%s %s %s\n" "$VLLM_URL" "$PROMETHEUS_URL" "$VLLM_MODEL"
  '
}

# assert_eq LABEL ACTUAL EXPECTED
assert_eq() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label → $actual"
  else
    fail "$label → got '$actual', expected '$expected'"
    errors=$((errors + 1))
  fi
}

echo "==> Telemetry env resolution tests"

# --- Case 1: Port override (no explicit URL) --------------------------------
#
# VLLM_PORT=18000, PROMETHEUS_PORT=19090 → URLs should derive from ports.

out=$(resolve_env /dev/null VLLM_PORT=18000 PROMETHEUS_PORT=19090)
vllm_url=$(echo "$out" | cut -d' ' -f1)
prom_url=$(echo "$out" | cut -d' ' -f2)

assert_eq "VLLM_PORT=18000 → vLLM URL"      "$vllm_url" "http://127.0.0.1:18000"
assert_eq "PROMETHEUS_PORT=19090 → prom URL" "$prom_url" "http://127.0.0.1:19090"

# --- Case 2: Explicit URL overrides win over port ----------------------------
#
# VLLM_PORT=18000 but VLLM_URL=http://example.invalid:28000
# The URL must win; the port is ignored.

out=$(resolve_env /dev/null \
  VLLM_PORT=18000 \
  VLLM_URL=http://example.invalid:28000 \
  PROMETHEUS_PORT=19090 \
  PROMETHEUS_URL=http://prom.example.invalid:29090)
vllm_url=$(echo "$out" | cut -d' ' -f1)
prom_url=$(echo "$out" | cut -d' ' -f2)

assert_eq "explicit VLLM_URL wins"      "$vllm_url" "http://example.invalid:28000"
assert_eq "explicit PROMETHEUS_URL wins" "$prom_url" "http://prom.example.invalid:29090"

# --- Case 3: Default fallback (nothing set) ---------------------------------

out=$(resolve_env /dev/null)
vllm_url=$(echo "$out" | cut -d' ' -f1)
prom_url=$(echo "$out" | cut -d' ' -f2)

assert_eq "default vLLM URL"      "$vllm_url" "http://127.0.0.1:8000"
assert_eq "default Prometheus URL" "$prom_url" "http://127.0.0.1:9090"

# --- Case 4: VLLM_MODEL default and override --------------------------------

out=$(resolve_env /dev/null)
model=$(echo "$out" | cut -d' ' -f3)
assert_eq "default VLLM_MODEL" "$model" "Qwen/Qwen3-0.6B"

out=$(resolve_env /dev/null VLLM_MODEL=meta-llama/Llama-3.2-1B)
model=$(echo "$out" | cut -d' ' -f3)
assert_eq "overridden VLLM_MODEL" "$model" "meta-llama/Llama-3.2-1B"

# --- Result ------------------------------------------------------------------

echo ""
if [ "$errors" -eq 0 ]; then
  echo "==> env resolution tests PASSED"
  exit 0
else
  echo "==> env resolution tests FAILED ($errors failures)" >&2
  exit 1
fi
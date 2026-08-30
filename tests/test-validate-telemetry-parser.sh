#!/usr/bin/env bash
#
# test-validate-telemetry-parser.sh — static tests for the Prometheus
# JSON parsing helper used by scripts/validate-telemetry.sh.
#
# These tests prevent regressions in Prometheus API response parsing:
#   - non-empty result vector with fractional timestamp → PASS
#   - empty result vector → FAIL
#   - error status response → FAIL
#   - malformed JSON → FAIL
#   - multiple result elements → PASS
#
# No GPU, Docker, or network required. Runs in CI.
#

# Do NOT use set -e here: we intentionally test functions that exit 1.
set -uo pipefail

# The python3 parser logic, identical to prom_result_nonempty() in
# validate-telemetry.sh. Duplicated here so this test is self-contained
# and does not depend on sourcing the full validation script.
prom_result_nonempty() {
  python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if d.get("status") != "success":
    sys.exit(1)
result = d.get("data", {}).get("result", [])
if not isinstance(result, list) or len(result) == 0:
    sys.exit(1)
sys.exit(0)
'
}

pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1" >&2; }
errors=0

# check_should_pass LABEL FIXTURE — expects prom_result_nonempty to exit 0.
check_should_pass() {
  local label="$1"
  local fixture="$2"
  if echo "$fixture" | prom_result_nonempty 2>/dev/null; then
    pass "$label → detected"
  else
    fail "$label → missed"
    errors=$((errors + 1))
  fi
}

# check_should_fail LABEL FIXTURE — expects prom_result_nonempty to exit 1.
check_should_fail() {
  local label="$1"
  local fixture="$2"
  if echo "$fixture" | prom_result_nonempty 2>/dev/null; then
    fail "$label → incorrectly accepted"
    errors=$((errors + 1))
  else
    pass "$label → correctly rejected"
  fi
}

echo "==> Prometheus JSON parser fixture tests"

# --- Fixture 1: Non-empty result with fractional timestamp -------------------
#
# This is the exact bug class that the old regex-based parser missed:
# Prometheus returns fractional timestamps like 1234567890.123 in the
# value array. The old regex `"value":[<integer>,"1"]` would fail to
# match.
fixture_nonempty='{"status":"success","data":{"resultType":"vector","result":[{"metric":{"__name__":"up","job":"vllm"},"value":[1234567890.123,"1"]}]}}'

check_should_pass "non-empty result with fractional timestamp" "$fixture_nonempty"

# --- Fixture 2: Empty result vector ------------------------------------------

fixture_empty='{"status":"success","data":{"resultType":"vector","result":[]}}'

check_should_fail "empty result vector" "$fixture_empty"

# --- Fixture 3: Error status -------------------------------------------------

fixture_error='{"status":"error","errorType":"bad_data","error":"invalid expression"}'

check_should_fail "error status response" "$fixture_error"

# --- Fixture 4: Malformed JSON -----------------------------------------------

check_should_fail "malformed JSON" "not valid json at all"

# --- Fixture 5: Multiple result elements (e.g. two GPUs) --------------------

fixture_multi='{"status":"success","data":{"resultType":"vector","result":[{"metric":{"__name__":"DCGM_FI_DEV_GPU_UTIL","gpu":"0"},"value":[1234567890.5,"42"]},{"metric":{"__name__":"DCGM_FI_DEV_GPU_UTIL","gpu":"1"},"value":[1234567890.5,"87"]}]}}'

check_should_pass "multiple result elements" "$fixture_multi"

# --- Result ------------------------------------------------------------------

echo ""
if [ "$errors" -eq 0 ]; then
  echo "==> parser tests PASSED"
  exit 0
else
  echo "==> parser tests FAILED ($errors failures)" >&2
  exit 1
fi
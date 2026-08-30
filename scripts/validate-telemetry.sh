#!/usr/bin/env bash
#
# validate-telemetry.sh — validate the running inference-observatory
# telemetry stack by querying Prometheus itself (not just curling
# endpoints directly).
#
# Validation sequence:
#   1.  Verify script prerequisites (curl, python3)
#   2.  Wait for Prometheus readiness (bounded retry)
#   3.  Wait for vLLM Prometheus target UP (bounded retry)
#   4.  Wait for DCGM Prometheus target UP (bounded retry)
#   5.  Verify a baseline vLLM metric exists in Prometheus
#   6.  Verify a baseline DCGM metric exists in Prometheus
#   7.  Send a tiny inference request (telemetry stimulus)
#   8.  Brief retry for request/token metric ingestion
#   9.  Verify a request/token-related vLLM metric is queryable
#   10. Print concise success summary
#
# Usage:
#   ./scripts/validate-telemetry.sh
#
# Environment:
#   OBSERVATORY_ENV_FILE          optional env file to source (set by Makefile)
#   PROMETHEUS_URL                default http://127.0.0.1:9090
#   VLLM_URL                      default http://127.0.0.1:8000
#   VLLM_MODEL                    default Qwen/Qwen3-0.6B
#   TELEMETRY_STARTUP_TIMEOUT_SECONDS   default 600
#
set -euo pipefail

# --- Load shared environment -------------------------------------------------
#
# If OBSERVATORY_ENV_FILE is set (by the Makefile), source it so the
# validator uses the same model/ports as Compose. deploy/.env is
# project-controlled local configuration; sourcing it is safe.
if [ -n "${OBSERVATORY_ENV_FILE:-}" ] && [ -f "${OBSERVATORY_ENV_FILE}" ]; then
  # shellcheck source=/dev/null
  . "${OBSERVATORY_ENV_FILE}"
fi

PROMETHEUS_URL="${PROMETHEUS_URL:-http://127.0.0.1:9090}"
VLLM_URL="${VLLM_URL:-http://127.0.0.1:8000}"
VLLM_MODEL="${VLLM_MODEL:-Qwen/Qwen3-0.6B}"
TIMEOUT_SECONDS="${TELEMETRY_STARTUP_TIMEOUT_SECONDS:-600}"

# Derive default port from the configured VLLM_PORT / PROMETHEUS_PORT if set.
if [ -z "${PROMETHEUS_URL:-}" ]; then
  PROMETHEUS_URL="http://127.0.0.1:${PROMETHEUS_PORT:-9090}"
fi
if [ -z "${VLLM_URL:-}" ]; then
  VLLM_URL="http://127.0.0.1:${VLLM_PORT:-8000}"
fi

pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1" >&2; }
info() { printf '       %s\n' "$1"; }

# --- JSON parsing helper (Step 1: prerequisites) -----------------------------

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required but not installed." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required for Prometheus JSON parsing but is not installed." >&2
  echo "       Install python3: https://www.python.org/downloads/" >&2
  exit 1
fi

# prom_result_nonempty — read Prometheus API JSON from stdin, exit 0 if
# the response status is "success" and the result vector is non-empty,
# exit 1 otherwise. Uses python3 stdlib only (no jq dependency).
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

# prom_query QUERY — run an instant PromQL query, print JSON to stdout.
prom_query() {
  curl -s "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=$1" 2>/dev/null
}

# prom_query_nonempty QUERY — return 0 if the query yields a non-empty
# result vector, 1 otherwise.
prom_query_nonempty() {
  prom_query "$1" 2>/dev/null | prom_result_nonempty
}

# --- Bounded retry helpers ---------------------------------------------------

# wait_for_http URL LABEL — bounded retry for an HTTP 200 response.
wait_for_http() {
  local url="$1"
  local label="$2"
  local elapsed=0
  printf '  [WAIT] %s (timeout %ss)\n' "$label" "$TIMEOUT_SECONDS"
  while [ "$elapsed" -lt "$TIMEOUT_SECONDS" ]; do
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
    if [ "$code" = "200" ]; then
      printf '  [PASS] %s responded (after %ss)\n' "$label" "$elapsed"
      return 0
    fi
    printf '       ...waiting (%ss/%ss, last code %s)\n' "$elapsed" "$TIMEOUT_SECONDS" "$code"
    sleep 5
    elapsed=$((elapsed + 5))
  done
  fail "$label did not respond within ${TIMEOUT_SECONDS}s"
  return 1
}

# wait_for_target_up JOB — bounded retry for a Prometheus scrape target
# to report UP. Queries `up{job="..."} == 1` and checks the result vector
# is non-empty via structured JSON parsing.
wait_for_target_up() {
  local job="$1"
  local elapsed=0
  printf '  [WAIT] Prometheus target %s UP (timeout %ss)\n' "$job" "$TIMEOUT_SECONDS"
  while [ "$elapsed" -lt "$TIMEOUT_SECONDS" ]; do
    if prom_query_nonempty "up{job=\"${job}\"} == 1" 2>/dev/null; then
      printf '  [PASS] %s target UP (after %ss)\n' "$job" "$elapsed"
      return 0
    fi
    printf '       ...waiting (%ss/%ss)\n' "$elapsed" "$TIMEOUT_SECONDS"
    sleep 5
    elapsed=$((elapsed + 5))
  done
  fail "Prometheus target ${job} did not become UP within ${TIMEOUT_SECONDS}s"
  return 1
}

# wait_for_metric METRIC LABEL — bounded retry for a PromQL instant
# query to return a non-empty result vector. Uses a shorter timeout
# (30s) since this is post-startup metric ingestion, not service boot.
wait_for_metric() {
  local metric="$1"
  local label="$2"
  local metric_timeout=30
  local elapsed=0
  printf '  [WAIT] %s (timeout %ss)\n' "$label" "$metric_timeout"
  while [ "$elapsed" -lt "$metric_timeout" ]; do
    if prom_query_nonempty "${metric}" 2>/dev/null; then
      printf '  [PASS] %s present (after %ss)\n' "$label" "$elapsed"
      return 0
    fi
    printf '       ...waiting (%ss/%ss)\n' "$elapsed" "$metric_timeout"
    sleep 3
    elapsed=$((elapsed + 3))
  done
  fail "$label not found within ${metric_timeout}s"
  return 1
}

# --- Validation sequence -----------------------------------------------------

echo "==> inference-observatory telemetry validation"
echo "    Prometheus: ${PROMETHEUS_URL}"
echo "    vLLM:       ${VLLM_URL}"
echo "    Model:      ${VLLM_MODEL}"
echo "    Timeout:    ${TIMEOUT_SECONDS}s"
echo ""

# --- 1. Prerequisites --------------------------------------------------------

echo "1/10 Script prerequisites"
pass "curl available"
pass "python3 available: $(python3 --version 2>&1)"
echo ""

# --- 2. Prometheus readiness -------------------------------------------------

echo "2/10 Prometheus readiness"
wait_for_http "${PROMETHEUS_URL}/-/ready" "Prometheus /-/ready" || exit 1
echo ""

# --- 3. vLLM target UP -------------------------------------------------------

echo "3/10 vLLM scrape target"
wait_for_target_up "vllm" || {
  info "Check: ${PROMETHEUS_URL}/api/v1/targets"
  info "Ensure vLLM started and /metrics is reachable at vllm:8000."
  exit 1
}
echo ""

# --- 4. DCGM target UP -------------------------------------------------------

echo "4/10 DCGM scrape target"
wait_for_target_up "dcgm" || {
  info "Check: ${PROMETHEUS_URL}/api/v1/targets"
  info "Ensure DCGM Exporter started and /metrics is reachable at dcgm-exporter:9400."
  exit 1
}
echo ""

# --- 5. Baseline vLLM metric -------------------------------------------------

echo "5/10 Baseline vLLM metric"
vllm_metric_found=""
for metric in \
  "vllm:num_requests_running" \
  "vllm:num_requests_waiting" \
  "vllm:kv_cache_usage_perc"; do
  if prom_query_nonempty "${metric}" 2>/dev/null; then
    vllm_metric_found="$metric"
    break
  fi
done
if [ -n "$vllm_metric_found" ]; then
  pass "Baseline vLLM metric present: ${vllm_metric_found}"
else
  fail "No baseline vLLM metric found in Prometheus"
  info "Expected at least one of: vllm:num_requests_running,"
  info "  vllm:num_requests_waiting, vllm:kv_cache_usage_perc"
  exit 1
fi
echo ""

# --- 6. Baseline DCGM metric -------------------------------------------------

echo "6/10 Baseline DCGM metric"
dcgm_metric_found=""
for metric in \
  "DCGM_FI_DEV_GPU_UTIL" \
  "DCGM_FI_DEV_FB_USED" \
  "DCGM_FI_DEV_GPU_TEMP" \
  "DCGM_FI_DEV_POWER_USAGE" \
  "DCGM_FI_DEV_SM_CLOCK"; do
  if prom_query_nonempty "${metric}" 2>/dev/null; then
    dcgm_metric_found="$metric"
    break
  fi
done
if [ -n "$dcgm_metric_found" ]; then
  pass "Baseline DCGM metric present: ${dcgm_metric_found}"
else
  fail "No baseline DCGM_FI_ metric found in Prometheus"
  info "Expected at least one of: DCGM_FI_DEV_GPU_UTIL, DCGM_FI_DEV_FB_USED,"
  info "  DCGM_FI_DEV_GPU_TEMP, DCGM_FI_DEV_POWER_USAGE, DCGM_FI_DEV_SM_CLOCK"
  exit 1
fi
echo ""

# --- 7. Inference request (telemetry stimulus) -------------------------------

echo "7/10 Inference request"
printf '       Sending tiny request to %s/v1/completions ...\n' "$VLLM_URL"
response=$(curl -s -w '\n%{http_code}' \
  "${VLLM_URL}/v1/completions" \
  -H 'Content-Type: application/json' \
  -d "{
    \"model\": \"${VLLM_MODEL}\",
    \"prompt\": \"Reply with the word telemetry.\",
    \"max_tokens\": 8,
    \"temperature\": 0
  }" 2>/dev/null || true)

http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
  pass "Inference request succeeded (HTTP 200)"
  info "Response received (content not validated for quality)."
else
  fail "Inference request failed (HTTP ${http_code})"
  info "Response body: ${body:0:300}"
  exit 1
fi
echo ""

# --- 8. Wait for request/token metric ingestion ------------------------------

echo "8/10 Wait for request/token metric ingestion"
request_metric_found=""
for metric in \
  "vllm:prompt_tokens_total" \
  "vllm:generation_tokens_total"; do
  if wait_for_metric "${metric}" "${metric}" 2>/dev/null; then
    request_metric_found="$metric"
    break
  fi
done
if [ -z "$request_metric_found" ]; then
  info "No request/token counter observed yet (may need more requests or time)."
fi
echo ""

# --- 9. Verify request/token metric ------------------------------------------

echo "9/10 Request/token metric verification"
if [ -n "$request_metric_found" ]; then
  pass "Request/token metric present: ${request_metric_found}"
else
  fail "No request/token metric found after inference request"
  info "Expected at least one of: vllm:prompt_tokens_total, vllm:generation_tokens_total"
  info "The request may not have completed, or vLLM may not have flushed metrics yet."
  exit 1
fi
echo ""

# --- 10. Success summary -----------------------------------------------------

echo "10/10 Summary"
echo ""
echo "==> telemetry validation PASSED"
echo "    Prometheus: both targets UP"
echo "    Baseline vLLM metric: ${vllm_metric_found}"
echo "    Baseline DCGM metric: ${dcgm_metric_found}"
echo "    Inference request: HTTP 200"
echo "    Request/token metric: ${request_metric_found}"
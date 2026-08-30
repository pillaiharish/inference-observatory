#!/usr/bin/env bash
#
# validate-telemetry.sh — validate the running inference-observatory
# telemetry stack by querying Prometheus itself (not just curling
# endpoints directly).
#
# Proves:
#   - Prometheus is ready
#   - the vllm scrape target is UP
#   - the dcgm scrape target is UP
#   - at least one vllm:* metric family is ingested
#   - at least one DCGM_FI_* metric family is ingested
#   - a tiny inference request succeeds (telemetry stimulus)
#
# Usage:
#   ./scripts/validate-telemetry.sh
#
# Environment:
#   PROMETHEUS_URL         default http://127.0.0.1:9090
#   VLLM_URL               default http://127.0.0.1:8000
#   VLLM_MODEL             default Qwen/Qwen3-0.6B
#   TELEMETRY_STARTUP_TIMEOUT_SECONDS  default 600
#
set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-http://127.0.0.1:9090}"
VLLM_URL="${VLLM_URL:-http://127.0.0.1:8000}"
VLLM_MODEL="${VLLM_MODEL:-Qwen/Qwen3-0.6B}"
TIMEOUT_SECONDS="${TELEMETRY_STARTUP_TIMEOUT_SECONDS:-600}"

pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1" >&2; }
info() { printf '       %s\n' "$1"; }

# require curl
if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required but not installed." >&2
  exit 1
fi

# wait_for URL LABEL — bounded retry loop.
# Returns 0 once the URL responds with HTTP 200, 1 on timeout.
wait_for() {
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

# prom_query QUERY — run an instant PromQL query, print JSON result.
prom_query() {
  curl -s "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=$1" 2>/dev/null
}

# target_up JOB — returns "true" if the named scrape job is UP in
# Prometheus, "false" otherwise.
target_up() {
  local job="$1"
  local result
  result=$(prom_query "up{job=\"${job}\"}" 2>/dev/null | grep -o '"value":\[[0-9]*,"1"\]' || true)
  if [ -n "$result" ]; then
    echo "true"
  else
    echo "false"
  fi
}

echo "==> inference-observatory telemetry validation"
echo "    Prometheus: ${PROMETHEUS_URL}"
echo "    vLLM:       ${VLLM_URL}"
echo "    Model:      ${VLLM_MODEL}"
echo "    Timeout:    ${TIMEOUT_SECONDS}s"
echo ""

# --- 1. Prometheus readiness -------------------------------------------------

echo "1/6  Prometheus readiness"
if wait_for "${PROMETHEUS_URL}/-/ready" "Prometheus /-/ready"; then
  :
else
  exit 1
fi

# --- 2. vLLM target UP -------------------------------------------------------

echo ""
echo "2/6  vLLM scrape target"
if [ "$(target_up vllm)" = "true" ]; then
  pass "Prometheus reports vllm target UP"
else
  fail "Prometheus does not report vllm target as UP"
  info "Check: ${PROMETHEUS_URL}/api/v1/targets"
  info "Ensure vLLM started and /metrics is reachable at vllm:8000 inside the Compose network."
  exit 1
fi

# --- 3. DCGM target UP -------------------------------------------------------

echo ""
echo "3/6  DCGM scrape target"
if [ "$(target_up dcgm)" = "true" ]; then
  pass "Prometheus reports dcgm target UP"
else
  fail "Prometheus does not report dcgm target as UP"
  info "Check: ${PROMETHEUS_URL}/api/v1/targets"
  info "Ensure DCGM Exporter started and /metrics is reachable at dcgm-exporter:9400 inside the Compose network."
  exit 1
fi

# --- 4. vLLM metric family present ------------------------------------------

echo ""
echo "4/6  vLLM metric family"
vllm_metric_found=""
for metric in \
  "vllm:num_requests_running" \
  "vllm:num_requests_waiting" \
  "vllm:kv_cache_usage_perc" \
  "vllm:prompt_tokens_total" \
  "vllm:generation_tokens_total"; do
  result=$(prom_query "${metric}" 2>/dev/null | grep -o '"metricName"' || true)
  if [ -n "$result" ]; then
    vllm_metric_found="$metric"
    break
  fi
done
if [ -n "$vllm_metric_found" ]; then
  pass "vLLM metric present: ${vllm_metric_found}"
else
  fail "No vLLM metric family found in Prometheus"
  info "Expected at least one of: vllm:num_requests_running, vllm:num_requests_waiting,"
  info "  vllm:kv_cache_usage_perc, vllm:prompt_tokens_total, vllm:generation_tokens_total"
  exit 1
fi

# --- 5. DCGM metric family present ------------------------------------------

echo ""
echo "5/6  DCGM metric family"
dcgm_metric_found=""
for metric in \
  "DCGM_FI_DEV_GPU_UTIL" \
  "DCGM_FI_DEV_FB_USED" \
  "DCGM_FI_DEV_GPU_TEMP" \
  "DCGM_FI_DEV_POWER_USAGE" \
  "DCGM_FI_DEV_SM_CLOCK"; do
  result=$(prom_query "${metric}" 2>/dev/null | grep -o '"metricName"' || true)
  if [ -n "$result" ]; then
    dcgm_metric_found="$metric"
    break
  fi
done
if [ -n "$dcgm_metric_found" ]; then
  pass "DCGM metric present: ${dcgm_metric_found}"
else
  fail "No DCGM_FI_ metric family found in Prometheus"
  info "Expected at least one of: DCGM_FI_DEV_GPU_UTIL, DCGM_FI_DEV_FB_USED,"
  info "  DCGM_FI_DEV_GPU_TEMP, DCGM_FI_DEV_POWER_USAGE, DCGM_FI_DEV_SM_CLOCK"
  exit 1
fi

# --- 6. Inference request (telemetry stimulus) -------------------------------

echo ""
echo "6/6  Inference request"
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
echo "==> telemetry validation PASSED"
echo "    Prometheus: both targets UP"
echo "    vLLM metrics: ${vllm_metric_found}"
echo "    DCGM metrics: ${dcgm_metric_found}"
echo "    Inference request: HTTP 200"
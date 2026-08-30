#!/usr/bin/env bash
#
# configure-github.sh — idempotent GitHub repository metadata setup for
# pillaiharish/inference-observatory.
#
# Configures: repository description, homepage, topics, and a
# restrained label taxonomy. Does NOT touch branch protection, merge
# rules, or secrets.
#
# This is an owner/admin helper. It is NOT run by CI and was NOT run
# during the foundation PR. Review it before executing.
#
# Requirements:
#   - GitHub CLI (gh) installed and authenticated
#   - the authenticated user must have admin rights on the repository
#
# Usage:
#   ./scripts/configure-github.sh            # apply description + topics + labels
#   ./scripts/configure-github.sh --dry-run  # print commands without running
#
set -euo pipefail

REPO="pillaiharish/inference-observatory"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# --- preflight ---------------------------------------------------------------

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) is not installed." >&2
  echo "Install: https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated. Run: gh auth login" >&2
  exit 1
fi

# --- repository description + topics ----------------------------------------

DESCRIPTION="Observability and performance diagnosis for LLM inference — vLLM metrics, NVIDIA GPU telemetry, profiling, dashboards and bottleneck analysis."

TOPICS=(
  llm-inference
  gpu-observability
  vllm
  cuda
  nvidia
  prometheus
  grafana
  dcgm
  opentelemetry
  pytorch
  gpu-profiling
  performance-engineering
  inference-optimization
)

echo "==> Setting description and topics on $REPO"
topic_arg=""
for t in "${TOPICS[@]}"; do
  if [ -n "$topic_arg" ]; then topic_arg+=","; fi
  topic_arg+="$t"
done
run gh repo edit "$REPO" \
  --description "$DESCRIPTION" \
  --add-topic "$topic_arg"

# --- labels ------------------------------------------------------------------

# Label taxonomy: name color description
LABELS=(
  "type/bug            d73a4a  Something is not working"
  "type/feature        a2eeef  New functionality"
  "type/docs           0075ca  Documentation improvement"
  "type/chore          d4c5f9  Maintenance / refactoring"

  "area/cli            c5def5  CLI command surface"
  "area/metrics        c5def5  Metric adapters and model"
  "area/vllm           c5def5  vLLM integration"
  "area/gpu            c5def5  NVIDIA / DCGM telemetry"
  "area/profiling      c5def5  PyTorch profiling"
  "area/diagnosis      c5def5  Diagnosis engine"
  "area/deployment     c5def5  Docker / deploy"
  "area/docs           0075ca  Documentation"

  "priority/p0         b60205  Top priority"
  "priority/p1         fbca04  Important"
  "priority/p2         0e8a16  Nice to have"

  "good first issue    7057ff  Good for newcomers"
  "help wanted         008672  Extra attention needed"
)

echo "==> Configuring labels on $REPO"
existing=""
if [ "$DRY_RUN" -eq 0 ]; then
  existing="$(gh label list --repo "$REPO" --json name -q '.[].name' 2>/dev/null || true)"
fi
for entry in "${LABELS[@]}"; do
  # split: name color description (description may contain spaces)
  set -- $entry
  name="$1"; color="$2"; desc="${entry#$name $color }"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] gh label %s %s color=%s desc=%q repo=%s\n' \
      "create-or-edit" "$name" "$color" "$desc" "$REPO"
    continue
  fi
  if printf '%s\n' "$existing" | grep -qx "$name"; then
    gh label edit "$name" --color "$color" --description "$desc" --repo "$REPO" >/dev/null
  else
    gh label create "$name" --color "$color" --description "$desc" --repo "$REPO" >/dev/null
  fi
done

echo "==> Done."
if [ "$DRY_RUN" -eq 1 ]; then
  echo "(dry-run: no changes were applied)"
fi
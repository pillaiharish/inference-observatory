#!/usr/bin/env bash
#
# preflight-gpu.sh — verify the host can run the inference-observatory
# telemetry stack.
#
# Checks (read-only, non-mutating):
#   - operating system is Linux
#   - docker is installed
#   - docker compose v2 is available
#   - nvidia-smi is available
#   - at least one NVIDIA GPU is visible
#   - Docker can access an NVIDIA GPU
#
# This script does NOT install software, does NOT use curl|bash, and
# does NOT mutate the machine. If a requirement is missing it prints a
# corrective message and exits non-zero.
#
# Usage:
#   ./scripts/preflight-gpu.sh
#
set -euo pipefail

pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1" >&2; }
info() { printf '       %s\n' "$1"; }

echo "==> inference-observatory telemetry preflight"

# --- OS ----------------------------------------------------------------------

if [ "$(uname -s)" != "Linux" ]; then
  fail "Operating system is $(uname -s), but the telemetry stack requires Linux with an NVIDIA GPU."
  info "macOS cannot run the live GPU stack. Static checks (make check, compose config) still work."
  exit 1
fi
pass "Linux"

# --- Docker ------------------------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
  fail "docker is not installed."
  info "Install Docker Engine: https://docs.docker.com/engine/install/"
  exit 1
fi
pass "docker installed: $(docker --version 2>&1)"

if ! docker info >/dev/null 2>&1; then
  fail "Docker daemon is not running."
  info "Start Docker, then re-run: ./scripts/preflight-gpu.sh"
  exit 1
fi
pass "Docker daemon is running"

# --- Docker Compose v2 -------------------------------------------------------

if ! docker compose version >/dev/null 2>&1; then
  fail "docker compose v2 is not available."
  info "Install Docker Compose v2: https://docs.docker.com/compose/install/"
  exit 1
fi
pass "docker compose v2: $(docker compose version --short 2>&1)"

# --- NVIDIA driver / nvidia-smi ---------------------------------------------

if ! command -v nvidia-smi >/dev/null 2>&1; then
  fail "nvidia-smi is not available."
  info "Install the NVIDIA driver: https://www.nvidia.com/drivers"
  exit 1
fi
pass "nvidia-smi available: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)"

gpu_count=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l)
if [ "${gpu_count:-0}" -lt 1 ]; then
  fail "No NVIDIA GPUs visible to nvidia-smi."
  exit 1
fi
pass "${gpu_count} GPU(s) visible to nvidia-smi"
nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader 2>/dev/null | while IFS=, read -r idx name mem; do
  info "  GPU ${idx}: ${name} (${mem})"
done

# --- Docker NVIDIA Container Toolkit ----------------------------------------

if ! docker run --rm --gpus all nvcr.io/nvidia/k8s/dcgm-exporter:4.6.0-4.8.3-distroless nvidia-smi --query-gpu=name --format=csv,noheader >/dev/null 2>&1; then
  fail "Docker cannot access an NVIDIA GPU."
  info "Install the NVIDIA Container Toolkit:"
  info "  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
  info "After installation, configure Docker with:"
  info "  sudo nvidia-ctk runtime configure --runtime=docker"
  info "  sudo systemctl restart docker"
  exit 1
fi
pass "Docker can access an NVIDIA GPU (NVIDIA Container Toolkit configured)"

echo "==> preflight passed — the host can run the telemetry stack."
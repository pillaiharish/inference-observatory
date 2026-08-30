# Scope

This document exists to prevent scope creep. It separates what V1
targets, what may come after V1, and what is explicitly deferred.

## V1

Targeted for the first stable release:

- NVIDIA GPUs
- 1 GPU and 2 GPUs
- vLLM as the inference backend
- Prometheus for metrics
- NVIDIA DCGM Exporter for GPU telemetry
- Grafana for visualization
- PyTorch Profiler for deep profiling
- Deterministic, evidence-based diagnosis rules
- Run / experiment comparison
- Docker-based deployment

V1 progresses single-GPU first, then two-GPU. Fleet/multi-node scope is
out of V1.

## Post-V1

Possible future work, not committed:

- SGLang adapter
- Triton adapter
- TensorRT-LLM adapter
- Kubernetes deployment
- OpenTelemetry expansion
- Additional profiling sources
- Fleet-level aggregation

## Explicitly deferred

These are out of scope for the foreseeable future unless explicitly
requested:

- AMD GPUs
- Multi-node distributed inference
- eBPF-based observability
- Autonomous tuning / remediation
- LLM-based diagnosis
- A custom time-series database
- A custom GPU exporter
- A custom visualization frontend
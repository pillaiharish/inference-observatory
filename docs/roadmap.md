# Roadmap

Staged milestones. Dates are not promised; performance claims are not
made. Each stage is delivered through reviewed PRs.

## v0.1 — Foundation

- repository structure
- Go CLI (`observatory version`)
- CI
- documentation (architecture, scope, roadmap)

**This is the current stage.**

## v0.2 — Telemetry stack

- vLLM deployment guidance
- Prometheus
- NVIDIA DCGM Exporter
- scrape validation

## v0.3 — Canonical metrics

- vLLM metric adapter
- DCGM adapter
- normalized internal representation
- metric discovery / validation

## v0.4 — Dashboards

- service overview
- GPU overview
- queue / KV visibility
- single-GPU baseline dashboard

## v0.5 — Diagnosis engine

Initial deterministic diagnoses:

- GPU saturation
- underutilized GPU
- request queue saturation
- prefill pressure
- decode pressure
- KV-cache pressure
- GPU-memory pressure
- thermal / power throttling

## v0.6 — Experiment correlation

- run IDs
- benchmark metadata
- time-window correlation
- baseline / current comparison

## v0.7 — Profiling

- PyTorch trace summary
- kernel / operator aggregation
- trace diff

## v0.8 — Two-GPU analysis

- per-GPU comparison
- utilization skew
- memory skew
- TP=2 visibility

## v0.9 — Hardening

- failure fixtures
- reproducibility
- integration tests
- documentation

## v1.0

Stable single- and dual-GPU observability and diagnosis workflow.
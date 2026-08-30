# inference-observatory

Observability and performance diagnosis for LLM inference — correlate
inference-server metrics, NVIDIA GPU telemetry, and profiling data to
explain performance bottlenecks.

**Status:** pre-alpha / active development. Nothing in this repository
collects, parses, or diagnoses metrics yet. See [Scope](docs/scope.md)
for what is implemented versus planned.

## Problem statement

Collecting metrics is not the same as diagnosing inference behaviour.
A dashboard may show that time-to-first-token (TTFT) rose, but it does
not explain *why*. To answer that, the observatory must correlate, over
a common observation window, signals that today live in separate tools:

- request behaviour (arrival rate, concurrency, batch size)
- queue behaviour (waiting / running requests)
- KV-cache state (usage, pressure, evictions)
- GPU utilization (SM activity)
- GPU memory (allocated, reserved, free)
- power and clocks (throttling, thermal)
- profiling traces (kernel / operator breakdown)
- benchmark / run metadata (which workload produced these numbers)

The goal is to turn that evidence into a deterministic, reproducible
explanation of inference bottlenecks rather than a wall of charts.

## Project goals

- GPU-aware LLM inference observability (NVIDIA first).
- A normalized inference metric model so diagnosis and reporting do
  not depend on backend-specific metric names.
- Metric correlation across a common observation interval and run id.
- Deterministic, evidence-based diagnosis rules.
- Experiment / run comparison (baseline vs current).
- Profiling integration (PyTorch Profiler traces).
- Single-GPU first, then two-GPU analysis.

## Non-goals

- A custom time-series database.
- A Grafana replacement.
- A custom NVIDIA exporter.
- LLM-based root-cause analysis in V1.
- Autonomous remediation / auto-tuning.
- Fleet-scale Kubernetes monitoring in V1.
- Generic application monitoring.

## Planned architecture

```mermaid
           benchmark / workload
                   |
                   v
                vLLM
              /      \
             /        \
    vLLM metrics      GPU
         |          telemetry
         |             |
         v             v
      Prometheus <--- DCGM
           |
           v
 inference-observatory
           |
   normalize/correlate
           |
       diagnose
       /      \
     CLI     Grafana
```

**Implemented now:** Go CLI `observatory version`, repository structure,
documentation, CI. **Planned for V1:** everything in the diagram above.
See [docs/architecture.md](docs/architecture.md) for the layer model
and [docs/scope.md](docs/scope.md) for the V1 boundaries.

## Initial support matrix (planned)

| Area                  | V1 target           | Status     |
|-----------------------|---------------------|------------|
| GPU vendor            | NVIDIA              | planned    |
| GPU count             | 1–2                 | planned    |
| Inference backend     | vLLM                | planned    |
| Metrics               | Prometheus          | planned    |
| GPU telemetry         | DCGM Exporter       | planned    |
| Visualization         | Grafana             | planned    |
| Deep profiling        | PyTorch Profiler    | planned    |
| Diagnosis             | deterministic rules | planned    |
| Deployment            | Docker first        | planned    |

## Quick start

Only the functionality that actually exists today is shown here. There
are no fake Prometheus or GPU commands.

```bash
make build
./bin/observatory version
make test
```

```text
$ ./bin/observatory version
inference-observatory dev
commit: unknown
built: unknown
```

```bash
./bin/observatory --help      # usage
./bin/observatory frobnicate  # unknown command -> non-zero exit
```

## Roadmap

See [docs/roadmap.md](docs/roadmap.md). This PR implements the
**v0.1 — Foundation** stage.

## Development

```bash
make build       # build bin/observatory with version metadata
make test        # go test ./...
make fmt         # gofmt -w .
make fmt-check   # fail if gofmt would change anything
make vet         # go vet ./...
make check       # fmt-check + vet + test
make clean       # remove build artefacts
```

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache-2.0. See [LICENSE](LICENSE).
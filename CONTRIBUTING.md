# Contributing to inference-observatory

Thanks for contributing. This guide is short on purpose.

## Workflow

1. Fork the repository and create a feature branch from `main`.
2. Keep PRs small and focused — one coherent goal per PR.
3. Run the local quality gate before pushing:

   ```bash
   make check
   ```

   `make check` runs `gofmt` check, `go vet`, and `go test ./...`.

4. Open a pull request against `main`. Fill in the PR template.
5. Do not merge your own PR. A reviewer will inspect it.
6. Call out anything you did not or could not test.

## Code expectations

- **Understand the subsystem before editing it.** Read
  `docs/architecture.md` and `docs/scope.md`.
- **Respect the adapter boundary.** Backend-specific metric names
  (vLLM, DCGM, ...) belong inside adapters under `internal/adapters/`.
  Canonical concepts belong outside adapters. Diagnosis and reporting
  must never depend on backend-specific metric names directly.
- **Keep collectors/adapters separate from diagnosis logic.** An
  adapter translates; it does not diagnose.
- **Diagnosis must cite measurable evidence.** No "probably" without a
  metric behind it.
- **Do not fabricate** benchmark results, screenshots, or GPU
  compatibility claims.
- **Single-GPU first, then two-GPU.** Avoid Kubernetes / fleet scope
  until explicitly requested.

## Tests and docs

- Add tests for new behaviour. Tests must not require a GPU, Docker,
  network, Prometheus, or root privileges.
- Update documentation for any user-visible behaviour change.
- Do not add generated benchmark claims.

## Commits

- Prefer a small number of logical commits.
- Do not squash or merge your own PR.

## Licensing

By contributing you agree your contributions are licensed under the
Apache-2.0 license, as described in `LICENSE`.
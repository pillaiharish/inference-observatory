# AGENTS.md

Guidance for coding agents (human or automated) working on
`inference-observatory`. Read this before making changes.

## Engineering principles

- Understand the relevant subsystem before editing it. Read
  `docs/architecture.md` and `docs/scope.md` first.
- Prefer existing ecosystem tools over reimplementation.
- Keep collectors/adapters separate from diagnosis logic.
- Backend-specific metric names belong inside adapters. Canonical
  concepts belong outside backend adapters.
- Diagnosis must cite measurable evidence.
- Do not introduce LLM-based diagnosis into V1.
- Do not fabricate benchmark results.
- Do not fabricate screenshots.
- Do not claim untested GPU compatibility.
- Preserve single-GPU first, then two-GPU progression.
- Avoid Kubernetes/fleet scope until explicitly requested.

## Quality gates

Before opening a PR, run the complete local quality gate:

```bash
make check
```

`make check` runs `gofmt` check, `go vet`, and `go test ./...`.

## PR behaviour

- One coherent goal per PR.
- Do not merge your own PR.
- Document validation in the PR body.
- Call out anything not tested.
- Do not silently widen scope.

See also `CONTRIBUTING.md` for the contributor workflow.
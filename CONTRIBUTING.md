# Contributing

## Prerequisites

- GNAT / GPRBuild toolchain
- OpenCL ICD loader and a development runtime (for example PoCL in CI/dev)

## Build

```bash
gprbuild -P tests/tests.gpr
```

## Smoke Tests

```bash
tools/run_smoke.sh
```

## Pull Requests

- Keep changes focused and traceable.
- Include tests/evidence for behavioral changes.
- Do not include build artifacts (`obj/`, `tests/obj/`, `tests/bin/`, `dist/`).
- Ensure local build and smoke pass before opening the PR.

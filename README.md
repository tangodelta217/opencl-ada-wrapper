# OCLW — Ada OpenCL Wrapper (RT no-JIT Kernel Packs)

[![CI](https://github.com/tangodelta217/opencl-ada-wrapper/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/tangodelta217/opencl-ada-wrapper/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/tangodelta217/opencl-ada-wrapper)](https://github.com/tangodelta217/opencl-ada-wrapper/releases)
[![License](https://img.shields.io/github/license/tangodelta217/opencl-ada-wrapper)](LICENSE)

OCLW is an Ada wrapper and runtime workflow for OpenCL with emphasis on deterministic runtime loading and auditable evidence.

It targets industrial and defense-style deployment constraints: no-JIT runtime paths, fail-closed checks, reproducible packaging, and traceable V&V artifacts.

## Quickstart: EW MLP Demo (RT no-JIT)

```bash
gprbuild -P tests/tests.gpr
tools/run_demo_ew_mlp.sh
OCLW_RUN_BENCH=1 tools/run_smoke.sh
```

- Demo showcase report: `docs/DEMO/EW_MLP_Showcase_Report.md`

## What This Repo Provides

- Thin FFI bindings for OpenCL (baseline 1.2-compatible usage in project architecture).
- Core Ada API for platforms, devices, contexts, queues, buffers, programs, kernels, and profiling paths.
- RT loader path for no-JIT execution using kernel packs (`manifest.kpack` + `program.bin`) with strict policy options.
- Reproducible evidence and delivery bundle tooling for release traceability.

## Demo: EW MLP

The EW MLP demo is designed as a fast credibility check of the full pipeline:

- BIT-EXACT CPU vs OpenCL inference behavior.
- RT_NOJIT execution mode with pack metadata and binary integrity evidence.
- Performance visibility via latency/throughput and benchmark gates (p50/p99 in bench reports).

- Primary demo evidence: `docs/DEMO/EW_MLP_Showcase_Report.md`

## Evidence and Audits

- Post-MLP audit: `docs/VV/Execution_Logs/GATES/G43/rerun_01/G43_Audit_Post_MLP.md`
- Reproducible evidence bundle rerun: `docs/VV/Execution_Logs/GATES/G37/rerun_03/G37_Evidence_Bundle_Report.md`
- Reproducible delivery bundle rerun: `docs/VV/Execution_Logs/GATES/G38/rerun_03/G38_Delivery_Bundle_Report.md`

## Release Assets

- Latest stable tag: `v0.2.1`
- Release assets are published via GitHub Releases and include reproducible bundle artifacts.

## Build Details

### Toolchain

- `gprbuild`
- `gnatls` (GNAT Ada toolchain)
- `gcc`

### Build

- Test build:

```bash
gprbuild -P tests/tests.gpr
```

- Combined build script:

```bash
./tools/build.sh
```

### OpenCL Link Configuration

Default Linux link flag is `-lOpenCL`.

Override example:

```bash
export OPENCL_LINK_FLAG=-lOpenCL
gprbuild -P tests/tests.gpr
```

Non-standard OpenCL location example:

```bash
export OPENCL_LINK_FLAG="-L/ruta/opencl -lOpenCL"
# or
export OPENCL_LINK_FLAG=/usr/lib/x86_64-linux-gnu/libOpenCL.so
```

## Repository Layout

```text
.
├── docs/
│   ├── ARCH/
│   ├── DEMO/
│   ├── REQ/
│   └── VV/
├── src/
├── tests/
│   ├── bench/
│   ├── demo/
│   ├── smoke/
│   └── support/
└── tools/
```

## Contributing

See `CONTRIBUTING.md`.

## Security

See `SECURITY.md`.

## License

Licensed under Apache-2.0. See `LICENSE`.

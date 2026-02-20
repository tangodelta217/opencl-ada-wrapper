# Changelog

All notable changes to this project are documented in this file.

## v0.2.1

### Added
- EW MLP demo end-to-end flow with deterministic dataset and CPU/OpenCL parity checks.
- RT no-JIT pack path for EW MLP (`gen_pack_ew_mlp`, `smoke_rt_load_pack_ew_mlp`).
- EW MLP benchmark path (`bench_rt_pack_ew_mlp`) with p50/p99 and throughput reporting.
- Consolidated demo/showcase and post-MLP audit evidence under VV gates.

### Updated
- README quickstart to prioritize EW MLP demo execution.
- Release notes aligned with reproducible bundle assets.

### Packaging and Evidence
- Reproducible evidence and delivery bundle reruns captured in:
  - `docs/VV/Execution_Logs/GATES/G37/rerun_03/`
  - `docs/VV/Execution_Logs/GATES/G38/rerun_03/`

## v0.1.0-rc1

### Added
- Baseline OpenCL Ada wrapper layers (raw/thick binding and smoke harness).
- RT-oriented no-JIT program binary path (pack generation and loading).
- Initial release and evidence packaging scripts.

### Security Hardening
- Fail-closed runtime policy for pack verification and loading.
- Fingerprint, hash, signature enforcement scaffolding and validation smokes.
- Filesystem and plugin trust hardening gates with documented evidence.

### Reproducibility
- Reproducible runtime/evidence/delivery bundle flows with deterministic checksums.


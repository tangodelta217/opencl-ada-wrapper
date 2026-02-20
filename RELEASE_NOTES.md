# v0.2.0 Release Notes

## Summary

This release consolidates RT no-JIT kernel pack execution, runtime hardening controls, and the EW MLP demo path with validated evidence gates.

- Release commit: `f56406f3230c99935e3962747990d46a464cbc8f`

## Highlights

- RT no-JIT execution path for kernel packs with strict runtime validation.
- Security hardening coverage for filesystem policy, TOCTOU, plugin trust policy, and fail-closed behavior.
- Deterministic EW MLP demo pipeline with CPU/OpenCL parity checks.
- Reproducible bundle workflows for runtime, evidence, and delivery packaging.
- Gate evidence expanded through post-MLP audits and reruns.

## How to Run Demo

`gprbuild -P tests/tests.gpr`

`tools/run_demo_ew_mlp.sh`

`OCLW_RUN_BENCH=1 tools/run_smoke.sh`

## Evidence

- `docs/DEMO/EW_MLP_Showcase_Report.md`
- `docs/VV/Execution_Logs/GATES/G43/rerun_01/G43_Audit_Post_MLP.md`

## Asset Checksums

- `9e922e1f2eb0709244240d0e2b791a717a3fd02fd589e824ab5e8010deda6975`  `dist/oclw_delivery_bundle_reproducible.tar.gz`
- `f1adfe480fa8e9506b3d58060029103d460ae59929bcccb0e84bd2f341b972b3`  `dist/oclw_evidence_bundle_reproducible.tar.gz`
- `1201bcfa860115107c13daab6b6d93866407ce5279f3844b4e737c2884c5f5a5`  `dist/oclw_rt_bundle_20260218T202951Z.tar.gz`
- `fcc36168aacdd838808df6ec70f83b3fe651d18687cfef212f7672d58776ab67`  `dist/oclw_rt_bundle_20260218T203050Z.tar.gz`
- `7e7e6a415b9d889e6d96807447c88956bd333dff983d00fddf01c72e5f3875cb`  `dist/oclw_rt_bundle_20260218T214717Z.tar.gz`
- `b9c321c0ebf86bb245f0c93d0937d12e13e6ae31ad9b09053b593d369ee4e233`  `dist/oclw_rt_bundle_20260219T103417Z.tar.gz`
- `369503e89c885854dd715317467876f5c8a83432b80e63aea7f7235d2581bf8d`  `dist/oclw_rt_bundle_reproducible.tar.gz`

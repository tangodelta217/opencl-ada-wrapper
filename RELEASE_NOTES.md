# Release v0.2.1

## Summary

This release delivers RT no-JIT kernel pack execution, reinforced RT hardening controls, and the EW MLP demo path with validated evidence.

The runtime path remains fail-closed and aligned with deterministic deployment workflows.

## Highlights

- RT no-JIT loading path for OpenCL kernel packs.
- Security hardening in RT policy and packaging workflow.
- EW MLP demo integrated end-to-end with runtime validation.
- Reproducible evidence and delivery bundles with tracked verification gates.

## How to run demo

`gprbuild -P tests/tests.gpr`

`tools/run_demo_ew_mlp.sh`

`OCLW_RUN_BENCH=1 tools/run_smoke.sh`

## Evidence

- `docs/DEMO/EW_MLP_Showcase_Report.md`
- `docs/VV/Execution_Logs/GATES/G43/rerun_01/G43_Audit_Post_MLP.md`
- `docs/VV/Execution_Logs/GATES/G37/rerun_03/G37_Evidence_Bundle_Report.md`
- `docs/VV/Execution_Logs/GATES/G38/rerun_03/G38_Delivery_Bundle_Report.md`

## Notes

OpenCL program binaries are vendor/driver/device-specific artifacts; RT policy enforces fail-closed behavior on mismatch.

## Assets checksums

- `9e922e1f2eb0709244240d0e2b791a717a3fd02fd589e824ab5e8010deda6975`  `dist/oclw_delivery_bundle_reproducible.tar.gz`
- `f1adfe480fa8e9506b3d58060029103d460ae59929bcccb0e84bd2f341b972b3`  `dist/oclw_evidence_bundle_reproducible.tar.gz`
- `1201bcfa860115107c13daab6b6d93866407ce5279f3844b4e737c2884c5f5a5`  `dist/oclw_rt_bundle_20260218T202951Z.tar.gz`
- `fcc36168aacdd838808df6ec70f83b3fe651d18687cfef212f7672d58776ab67`  `dist/oclw_rt_bundle_20260218T203050Z.tar.gz`
- `7e7e6a415b9d889e6d96807447c88956bd333dff983d00fddf01c72e5f3875cb`  `dist/oclw_rt_bundle_20260218T214717Z.tar.gz`
- `b9c321c0ebf86bb245f0c93d0937d12e13e6ae31ad9b09053b593d369ee4e233`  `dist/oclw_rt_bundle_20260219T103417Z.tar.gz`
- `369503e89c885854dd715317467876f5c8a83432b80e63aea7f7235d2581bf8d`  `dist/oclw_rt_bundle_reproducible.tar.gz`

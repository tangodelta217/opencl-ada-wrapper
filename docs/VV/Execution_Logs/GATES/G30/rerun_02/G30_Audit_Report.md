# G30 Audit Report (rerun_02)

- UTC timestamp: 2026-02-19T11:06:46Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Inputs
- Gate inventory log: docs/VV/Execution_Logs/GATES/G30/rerun_02/01_gate_inventory.log
- Build log: docs/VV/Execution_Logs/GATES/G30/rerun_02/02_build.log
- Run smoke log: docs/VV/Execution_Logs/GATES/G30/rerun_02/03_run_smoke.log
- Bundle reproducibility log: docs/VV/Execution_Logs/GATES/G30/rerun_02/04_bundle_repro.log

## Gate Inventory Summary
- Critical gates checked (G0..G29 + G13A1): 31
- Critical reports found: 31
- Critical reports missing: 0
- Missing critical gates: <none>
- Optional targets summary: G12_INTEL|dir=YES|report=docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/Acceptance_Report.md|closure=MISSING|status=REPORT_OK;G12_AMD|dir=NO|status=NOT_PRESENT_OPTIONAL;G12_AMD_XRT|dir=YES|report=docs/VV/Execution_Logs/GATES/G12_AMD_XRT/rerun_01/Acceptance_Report.md|closure=MISSING|status=REPORT_OK;

## Build + Smoke
- Build exit code: 0
- Run smoke exit code: 0
- Build log marker: build_exit_code=0
- Run log marker: run_smoke_exit_code=0
- Internal smoke marker: smoke_exit_code=0

## Reproducible Bundle Check
- Result: PASS
- Run1 exit code: 0
- Run2 exit code: 0
- Hash command: sha256sum
- Hash run1: f6a2d90e10c33861ce906b61b55c51fda1267691b54c72c71c0a2d6befc16b15
- Hash run2: f6a2d90e10c33861ce906b61b55c51fda1267691b54c72c71c0a2d6befc16b15
- Tar run1: dist/oclw_rt_bundle_reproducible.tar.gz
- Tar run2: dist/oclw_rt_bundle_reproducible.tar.gz

## Final Conclusion
- RESULT=PASS
- Reasons=none
- Rule applied: FAIL if build/smoke fail, critical reports missing, or bundle reproducibility check is not PASS.

# G30 Audit Report

- UTC timestamp: 2026-02-19T08:14:14Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Inputs
- Gate inventory log: `docs/VV/Execution_Logs/GATES/G30/rerun_01/01_gate_inventory.log`
- Build log: `docs/VV/Execution_Logs/GATES/G30/rerun_01/02_build.log`
- Run smoke log: `docs/VV/Execution_Logs/GATES/G30/rerun_01/03_run_smoke.log`
- Bundle reproducibility log: `docs/VV/Execution_Logs/GATES/G30/rerun_01/04_bundle_repro.log`

## Gate Inventory Summary
- Critical gates checked (G0..G29 + G13A1): 31
- Critical reports found: 21
- Critical reports missing: 10
- Missing critical gates: G20 G21 G22 G23 G24 G25 G26 G27 G28 G29
- Optional targets summary: G12_INTEL|dir=YES|report=docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/Acceptance_Report.md|closure=MISSING|status=REPORT_OK;G12_AMD|dir=NO|status=NOT_PRESENT_OPTIONAL;G12_AMD_XRT|dir=YES|report=docs/VV/Execution_Logs/GATES/G12_AMD_XRT/rerun_01/Acceptance_Report.md|closure=MISSING|status=REPORT_OK;

## Build + Smoke
- Build exit code: 0
- Run smoke exit code: 0
- Build log marker: build_exit_code=0
- Run log marker: run_smoke_exit_code=0
- Internal smoke marker: smoke_exit_code=0

## Reproducible Bundle (best-effort)
- Script: tools/package_rt_bundle.sh
- Result: FAIL
- Run1 exit code: 0
- Run2 exit code: 0
- Hash command: sha256sum
- Hash run1: 04b81e628865735a5672324d07dac51f3993fe0a5eabec7352af81dc48594436
- Hash run2: 0cadb76749a848ec37dfda6826f5e0d8eed65cf33a49f3087a0cca926427613d
- Tar run1: dist/oclw_rt_bundle_reproducible.tar.gz
- Tar run2: dist/oclw_rt_bundle_reproducible.tar.gz

## Final Conclusion
- RESULT=FAIL
- Reasons=critical_gate_reports_missing
- Rule applied: FAIL if build/smoke fail or critical gate reports are missing.

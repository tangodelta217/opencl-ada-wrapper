# G35 Release Candidate Audit

- UTC timestamp: 2026-02-19T20:29:12Z
- git HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Evidence Inventory
- Inventory log: docs/VV/Execution_Logs/GATES/G35/rerun_01/01_inventory.log
- Critical reports missing: 0
- Required closures missing (G31..G34): 0
- Optional closure warnings (G12 targets): 0

### Inventory Extract
```text
6:PASS report_exists: docs/VV/Execution_Logs/GATES/G30/rerun_02/G30_Audit_Report.md
7:PASS report_exists: docs/VV/Execution_Logs/GATES/G25/rerun_02/G25_Report.md
8:PASS report_exists: docs/VV/Execution_Logs/GATES/G34/rerun_01/G34_Security_Audit_Report.md
9:PASS report_exists: docs/VV/Execution_Logs/GATES/G31/rerun_01/G31_Report.md
10:PASS report_exists: docs/VV/Execution_Logs/GATES/G32/rerun_01/G32_Report.md
11:PASS report_exists: docs/VV/Execution_Logs/GATES/G33/rerun_01/G33_Report.md
14:PASS closure_exists: docs/VV/Execution_Logs/GATES/G31/Closure.md
15:PASS closure_exists: docs/VV/Execution_Logs/GATES/G32/Closure.md
16:PASS closure_exists: docs/VV/Execution_Logs/GATES/G33/Closure.md
17:PASS closure_exists: docs/VV/Execution_Logs/GATES/G34/Closure.md
20:INFO optional_report_present: docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/Acceptance_Report.md
21:PASS optional_closure_exists: docs/VV/Execution_Logs/GATES/G12_INTEL/Closure.md
22:INFO optional_report_present: docs/VV/Execution_Logs/GATES/G12_AMD_XRT/rerun_01/Acceptance_Report.md
23:PASS optional_closure_exists: docs/VV/Execution_Logs/GATES/G12_AMD_XRT/Closure.md
```

## Build and Smoke
- Build command: gprbuild -P tests/tests.gpr
- Build exit code: 0
- Build log: docs/VV/Execution_Logs/GATES/G35/rerun_01/02_build.log
- Smoke command: tools/run_smoke.sh
- Smoke exit code: 0
- Smoke log: docs/VV/Execution_Logs/GATES/G35/rerun_01/03_run_smoke.log

### Security Smokes (current run)
- smoke_rt_pack_symlink_escape: RESULT=PASS (smoke_rt_pack_symlink_escape_exit_code=0)
- smoke_rt_toctou_manifest_swap: RESULT=PASS (smoke_rt_toctou_manifest_swap_exit_code=0)
- smoke_rt_toctou_binary_swap: RESULT=PASS (smoke_rt_toctou_binary_swap_exit_code=0)
- smoke_rt_plugin_allowlist_policy: RESULT=PASS (smoke_rt_plugin_allowlist_policy_exit_code=0)

## Reproducible Bundle Check
- Log: docs/VV/Execution_Logs/GATES/G35/rerun_01/04_bundle_repro.log
- Result: PASS
- sha1: f5d21db5eaa4f6ea8f0ee32fba3bcb63507adc92863e68419a877037c501d051
- sha2: f5d21db5eaa4f6ea8f0ee32fba3bcb63507adc92863e68419a877037c501d051

## Decision Rules
- FAIL if build/smoke fails.
- FAIL if critical reports are missing.
- FAIL if reproducible bundle check is not PASS.
- FAIL if required hardening closures G31..G34 are missing.

## Final
RESULT=PASS

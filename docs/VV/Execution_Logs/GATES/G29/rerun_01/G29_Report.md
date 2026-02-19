# G29 Report (Backfill rerun_01)

- UTC timestamp: 2026-02-19T10:38:44Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G29/rerun_01/01_build.log`

## Run
- Exit code: 0
- Missing executables: 0
- Log: `docs/VV/Execution_Logs/GATES/G29/rerun_01/02_run.log`

## Extracts
- Source: `docs/VV/Execution_Logs/GATES/G29/rerun_01/03_extracts.log`

```text
$ ./tools/g12_target_intel_aocl_check.sh 
RESULT=SKIP reason=stack_not_installed_or_incomplete
g12_target_intel_aocl_check_exit_code=0
$ ./tools/g12_target_amd_xrt_check.sh 
RESULT=SKIP reason=stack_not_installed_or_incomplete
g12_target_amd_xrt_check_exit_code=0
run_exit_code=0
```

## Final
- RESULT=SKIP
- Reason=result_skip_expected

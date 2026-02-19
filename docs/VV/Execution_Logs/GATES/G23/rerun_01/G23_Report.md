# G23 Report (Backfill rerun_01)

- UTC timestamp: 2026-02-19T10:38:44Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G23/rerun_01/01_build.log`

## Run
- Exit code: 0
- Missing executables: 0
- Log: `docs/VV/Execution_Logs/GATES/G23/rerun_01/02_run.log`

## Extracts
- Source: `docs/VV/Execution_Logs/GATES/G23/rerun_01/03_extracts.log`

```text
$ ./tests/bin/smoke_program_il_path 
INFO il_dummy_bytes= 8
INFO create_from_il_status=CL_INVALID_VALUE status_int=-30
RESULT=SKIP reason=il_create_controlled_failure
smoke_program_il_path_exit_code=0
run_exit_code=0
```

## Final
- RESULT=SKIP
- Reason=result_skip_expected

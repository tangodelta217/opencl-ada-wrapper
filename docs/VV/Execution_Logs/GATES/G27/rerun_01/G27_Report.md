# G27 Report (Backfill rerun_01)

- UTC timestamp: 2026-02-19T10:38:44Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G27/rerun_01/01_build.log`

## Run
- Exit code: 0
- Missing executables: 0
- Log: `docs/VV/Execution_Logs/GATES/G27/rerun_01/02_run.log`

## Extracts
- Source: `docs/VV/Execution_Logs/GATES/G27/rerun_01/03_extracts.log`

```text
$ ./tools/run_gnatprove_optional.sh 
RESULT=SKIP
INFO reason=gnatprove_not_found
run_gnatprove_optional_exit_code=0
$ env OCLW_FUZZ_ITERS=500 OCLW_FUZZ_SEED=1 ./tests/bin/smoke_fuzz_kpack_parser
INFO iters=500
INFO seed=1
INFO corpus_cases=10
INFO failures=0
INFO crashes=0
INFO saved_artifact=<none>
RESULT=PASS
smoke_fuzz_kpack_parser_exit_code=0
run_exit_code=0
```

## Final
- RESULT=PASS
- Reason=result_pass

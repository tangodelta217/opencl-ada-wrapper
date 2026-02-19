# Gate G15 Fuzzing Report

- UTC: 2026-02-19T00:56:53Z
- git HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G15/rerun_01/01_build.log`

## Run
- Command: `tools/run_smoke.sh`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G15/rerun_01/02_run_smoke.log`

## Fuzz Extract (smoke_fuzz_kpack_parser)
- Extract log: `docs/VV/Execution_Logs/GATES/G15/rerun_01/03_extracts.log`

```text
$ env OCLW_FUZZ_ITERS=500 OCLW_FUZZ_SEED=1 /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_fuzz_kpack_parser
INFO iters=500
INFO seed=1
INFO corpus_cases=10
INFO failures=0
INFO crashes=0
INFO saved_artifact=<none>
RESULT=PASS
smoke_fuzz_kpack_parser_exit_code=0
```

## Final Result
PASS

# G15 Rerun 02 Report (Long Fuzz)

- UTC timestamp: 2026-02-19T08:24:22Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G15/rerun_02/01_build.log`

## Fuzz (extended)
- Command: `env OCLW_FUZZ_ITERS=20000 OCLW_FUZZ_SEED=1 ./tests/bin/smoke_fuzz_kpack_parser`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G15/rerun_02/02_fuzz_long.log`

## Extract
- Source: `docs/VV/Execution_Logs/GATES/G15/rerun_02/03_extracts.log`
- iters: INFO iters=20000
- seed: INFO seed=1
- failures: INFO failures=0
- crashes: INFO crashes=0
- RESULT: RESULT=PASS

```text
== smoke_fuzz_kpack_parser (long) ==
INFO iters=20000
INFO seed=1
INFO corpus_cases=10
INFO failures=0
INFO crashes=0
INFO saved_artifact=<none>
RESULT=PASS
```

## Final
- Build status: PASS
- Fuzz status: PASS

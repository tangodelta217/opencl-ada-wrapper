# Gate G43 Audit Post-MLP

- UTC timestamp: 2026-02-20T11:08:54Z
- HEAD: `374d9a880c9d58ead4e3bcda4beb588ef3956dcd`

## Execution Summary

- Build command: `gprbuild -P tests/tests.gpr`
  - exit code: `0`
  - log: `docs/VV/Execution_Logs/GATES/G43/rerun_01/01_build.log`
- Smoke command: `tools/run_smoke.sh`
  - exit code: `0`
  - log: `docs/VV/Execution_Logs/GATES/G43/rerun_01/02_run_smoke.log`
- Demo command: `tools/run_demo_ew_mlp.sh`
  - exit code: `0`
  - log: `docs/VV/Execution_Logs/GATES/G43/rerun_01/03_run_demo.log`
- Bench command: `OCLW_RUN_BENCH=1 tools/run_smoke.sh`
  - status: `PASS`
  - exit code: `0`
  - log: `docs/VV/Execution_Logs/GATES/G43/rerun_01/04_run_bench.log`

## Evidence and Closure Presence Check (G39..G42)

All required files were found:

- `docs/VV/Execution_Logs/GATES/G39/rerun_01/G39_Report.md`
- `docs/VV/Execution_Logs/GATES/G40/rerun_02/G40_Report.md`
- `docs/VV/Execution_Logs/GATES/G41/rerun_01/G41_Report.md`
- `docs/VV/Execution_Logs/GATES/G42/rerun_01/G42_Report.md`
- `docs/VV/Execution_Logs/GATES/G39/Closure.md`
- `docs/VV/Execution_Logs/GATES/G40/Closure.md`
- `docs/VV/Execution_Logs/GATES/G41/Closure.md`
- `docs/VV/Execution_Logs/GATES/G42/Closure.md`

Check log: `docs/VV/Execution_Logs/GATES/G43/rerun_01/05_checks.log`

## Key Extracts

Demo extract:

```text
INFO mode=RT_NOJIT
INFO accuracy=1024/1024
RESULT=PASS
```

Bench extract (`bench_rt_pack_ew_mlp`):

```text
INFO init_ns=22082093
INFO exec_host_ns_p50=7060013
INFO exec_host_ns_p99=11081682
INFO vectors_per_sec=37914
RESULT=PASS
```

Extract log: `docs/VV/Execution_Logs/GATES/G43/rerun_01/06_extracts.log`

## Conclusion

- RESULT=PASS

Closure criteria satisfied: build, smoke, demo, and bench completed successfully, and required evidence/closures for G39..G42 are present.

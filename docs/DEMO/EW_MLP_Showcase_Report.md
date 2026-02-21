# EW MLP Showcase Report

- UTC: 2026-02-20T10:59:23Z
- HEAD: `374d9a880c9d58ead4e3bcda4beb588ef3956dcd`

## What This Demonstrates

- Bit-exact inference equivalence between Ada CPU reference and OpenCL execution.
- RT no-JIT execution path using Kernel Pack (`manifest.kpack` + `program.bin`).
- Performance visibility with deterministic benchmark outputs (init + p50/p99 + throughput).

## How To Run

```bash
gprbuild -P tests/tests.gpr
tools/run_demo_ew_mlp.sh
OCLW_RUN_BENCH=1 tools/run_smoke.sh
```

## Key Evidence Extracts

### G39 (MLP build-from-source smoke)
Primary report: `docs/VV/Execution_Logs/GATES/G39/rerun_01/G39_Report.md`

```text
INFO accuracy=256/256
INFO confusion_row_0=64,0,0,0
INFO confusion_row_1=0,64,0,0
INFO confusion_row_2=0,0,64,0
INFO confusion_row_3=0,0,0,64
RESULT=PASS
```

### G40 rerun_02 (RT no-JIT MLP pack load)
Primary report: `docs/VV/Execution_Logs/GATES/G40/rerun_02/G40_Report.md`

```text
RESULT=PASS
INFO binary_size=78916
INFO binary_fnv1a32=28693229
```

### G41 (demo entrypoint)
Primary report: `docs/VV/Execution_Logs/GATES/G41/rerun_01/G41_Report.md`

```text
INFO mode=RT_NOJIT
INFO accuracy=1024/1024
RESULT=PASS
```

### G42 (RT benchmark)
Primary report: `docs/VV/Execution_Logs/GATES/G42/rerun_01/G42_Report.md`

```text
RESULT=PASS
INFO init_ns=23257869
INFO exec_host_ns_p50=5189156
INFO exec_host_ns_p99=11500207
INFO vectors_per_sec=46185
```

## Security Notes (RT)

RT loading is enforced fail-closed: pack metadata, fingerprint matching, and binary integrity checks are required before execution. Kernel binaries are vendor/driver/device-specific artifacts, so portability across heterogeneous targets is not assumed; deployment must use controlled offline pack generation and target-matched fingerprints.

## Full Reports

- `docs/VV/Execution_Logs/GATES/G39/rerun_01/G39_Report.md`
- `docs/VV/Execution_Logs/GATES/G40/rerun_02/G40_Report.md`
- `docs/VV/Execution_Logs/GATES/G41/rerun_01/G41_Report.md`
- `docs/VV/Execution_Logs/GATES/G42/rerun_01/G42_Report.md`

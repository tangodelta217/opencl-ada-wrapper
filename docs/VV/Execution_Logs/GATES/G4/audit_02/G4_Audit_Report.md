# G4 Audit Report (audit_02)

- UTC timestamp: 2026-02-18T02:06:40Z
- HEAD: 776cb97208dc5054559e8251c831989aef759c63
- Overall: **PASS**

## Checklist A-E

| Item | Result | Basis |
| --- | --- | --- |
| A) Docs (SDD Program binaries/no-JIT + ADR-0007) | PASS | 01_static_checks.log |
| B) Raw/FFI symbols present | PASS | 01_static_checks.log |
| C) Thick binding symbols present | PASS | 01_static_checks.log |
| D) Tests/Harness wiring + POCL_CACHE_DIR | PASS | 01_static_checks.log |
| E) Execution (build/run/result/binary_size>0) | PASS | 02_build.log, 03_run_smoke.log, 04_extracts.log |

## Execution extracts

- smoke_program_binary_roundtrip RESULT: RESULT=PASS
- smoke_program_binary_roundtrip binary_size: INFO binary_size=48617
- smoke_program_binary_roundtrip fnv1a32: INFO binary_fnv1a32=166242793
- POCL_CACHE_DIR used: pocl_cache_dir=/home/tangodelta/opencl-ada-wrapper/.pocl_kcache
- build_exit_code: 0
- run_smoke_exit_code: 0

## Evidence files

- docs/VV/Execution_Logs/GATES/G4/audit_02/00_context.log
- docs/VV/Execution_Logs/GATES/G4/audit_02/01_static_checks.log
- docs/VV/Execution_Logs/GATES/G4/audit_02/02_build.log
- docs/VV/Execution_Logs/GATES/G4/audit_02/03_run_smoke.log
- docs/VV/Execution_Logs/GATES/G4/audit_02/04_extracts.log

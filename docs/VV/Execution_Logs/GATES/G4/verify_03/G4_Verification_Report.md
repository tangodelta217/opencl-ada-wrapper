# G4 Verification Report (verify_03)

- Timestamp UTC: 2026-02-18T02:35:44Z
- HEAD: 776cb97208dc5054559e8251c831989aef759c63
- Overall: **PASS**

## Checklist A-E

| Criterion | Status | Evidence |
| --- | --- | --- |
| A) Docs: SDD Program binaries/no-JIT + ADR-0007 | PASS | 01_static_checks.log |
| B) Raw/FFI symbols present | PASS | 01_static_checks.log |
| C) Thick Programs API symbols present | PASS | 01_static_checks.log |
| D) Tests/Harness wiring + POCL_CACHE_DIR | PASS | 01_static_checks.log |
| E) Execution: build/run OK + RESULT=PASS + binary_size>0 | PASS | 02_build.log, 03_run_smoke.log, 04_extracts.log |

## References

- docs/VV/Execution_Logs/GATES/G4/verify_03/01_static_checks.log
- docs/VV/Execution_Logs/GATES/G4/verify_03/02_build.log
- docs/VV/Execution_Logs/GATES/G4/verify_03/03_run_smoke.log
- docs/VV/Execution_Logs/GATES/G4/verify_03/04_extracts.log

## Extracts (04_extracts.log)

```text
result_line=RESULT=PASS
binary_size_line=INFO binary_size=48617
binary_fnv1a32_line=INFO binary_fnv1a32=3287865993
pocl_cache_dir_line=pocl_cache_dir=/home/tangodelta/opencl-ada-wrapper/.pocl_kcache
binary_size_value=48617
extract_validation=PASS
extracts_exit_code=0
```

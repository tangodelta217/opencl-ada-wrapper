# Requirements Traceability (G0)

## Scope

This matrix captures minimum G0 traceability between selected requirements,
smoke tests, and verification evidence.

Primary gate evidence:
- `docs/VV/Execution_Logs/GATES/G0/rerun_04/G0_Report.md`

Related test evidence:
- `docs/VV/Execution_Logs/2026-02-09_OCLW-TST-0001_smoke.md`
- `docs/VV/Execution_Logs/2026-02-09_OCLW-TST-0002_smoke_platforms.md`

## Matrix

| Requirement ID | Requirement focus | Verification method | Test ID | Test implementation | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| OCLW-REQ-0001 | Raw/Thin OpenCL 1:1 FFI baseline | Inspection + test | OCLW-TST-0002 | `tests/smoke/smoke_platforms.adb` + `src/opencl/raw/opencl-raw-api.ads` | `docs/VV/Execution_Logs/GATES/G0/rerun_04/G0_Report.md` (build + link + run) | PASS (G0 scope) |
| OCLW-REQ-0003 | Runtime enumeration of platform/device capabilities | Test | OCLW-TST-0002 | `tests/smoke/smoke_platforms.adb` | `docs/VV/Execution_Logs/GATES/G0/rerun_04/G0_Report.md` (platform/device enumeration path) | PASS (no-platform case covered) |
| OCLW-REQ-0005 | Explicit OpenCL error handling behavior | Test | OCLW-TST-0002 | `tests/smoke/smoke_platforms.adb` | `docs/VV/Execution_Logs/GATES/G0/rerun_04/G0_Report.md` (`CL_PLATFORM_NOT_FOUND_KHR` handled) | PASS (G0 smoke behavior) |
| OCLW-REQ-0007 | Ada 2012/2022 compatibility at public API/build level | Analysis + build | OCLW-TST-0002 | `tests/tests.gpr`, thin binding build path | `docs/VV/Execution_Logs/GATES/G0/rerun_04/G0_Report.md` (successful compile/link/run) | PASS (current toolchain) |
| OCLW-REQ-0010 | REQ-to-test traceability maintained | Inspection | OCLW-TST-0001, OCLW-TST-0002 | docs + smoke artifacts | This document + `docs/VV/Execution_Logs/GATES/G0/Closure.md` | PASS |

## Notes

- G0 verifies baseline build/link/smoke behavior only.
- Full feature conformance remains subject to later gates.

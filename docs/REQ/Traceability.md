# Requirements Traceability (G0/G1/G2/G3/G4)

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

## G1 Addendum (Errors/Core)

Primary gate evidence:
- `docs/VV/Execution_Logs/GATES/G1/rerun_01/G1_Report.md`
- `docs/VV/Execution_Logs/GATES/G1/Closure.md`

| Requirement ID | Requirement focus | Verification method | Test ID | Implementation mapping | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| OCLW-REQ-0002 | Core/Thick minimum abstraction for host enumeration | Inspection + test | OCLW-TST-0002 | `src/opencl/core/opencl-core.ads`, `src/opencl/core/opencl-core.adb`, `tests/smoke/smoke_core.adb` | `docs/VV/Execution_Logs/GATES/G1/rerun_01/G1_Report.md` (build + smoke_core run) | PASS (G1 scope) |
| OCLW-REQ-0003 | Runtime enumeration of platform/device capabilities via Core API | Test | OCLW-TST-0002 | `src/opencl/core/opencl-core.adb`, `tests/smoke/smoke_core.adb` | `docs/VV/Execution_Logs/GATES/G1/rerun_01/G1_Report.md` (platform/device enumeration path) | PASS (no-platform case covered) |
| OCLW-REQ-0005 | Explicit error model and status reporting in non-exception primary flow | Inspection + test | OCLW-TST-0002 | `src/opencl/opencl-errors.ads`, `src/opencl/opencl-errors.adb`, `src/opencl/core/opencl-core.adb`, `tests/smoke/smoke_core.adb` | `docs/VV/Execution_Logs/GATES/G1/rerun_01/G1_Report.md` (`CL_PLATFORM_NOT_FOUND_KHR` reported via status/image) | PASS |
| OCLW-REQ-0007 | Ada 2012/2022 compatible public API/build path with Core additions | Analysis + build | OCLW-TST-0002 | `src/opencl/opencl-errors.*`, `src/opencl/core/opencl-core.*`, `opencl_wrapper.gpr`, `tests/tests.gpr` | `docs/VV/Execution_Logs/GATES/G1/rerun_01/G1_Report.md` (successful compile/link/run for both smokes) | PASS |
| OCLW-REQ-0010 | End-to-end REQ -> implementation -> test -> evidence traceability | Inspection | OCLW-TST-0001, OCLW-TST-0002 | This document + Gate closure artifacts | `docs/VV/Execution_Logs/GATES/G1/Closure.md` | PASS |

## G2 Addendum (Context/Queue/Buffer I/O)

Primary gate evidence:
- `docs/VV/Execution_Logs/GATES/G2/rerun_01/G2_Report.md`
- `docs/VV/Execution_Logs/GATES/G2/Closure.md`

| Requirement ID | Requirement focus | Verification method | Test ID | Implementation mapping | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| OCLW-REQ-0001 | Thin FFI expansion for context/queue/buffer primitives | Inspection + build | OCLW-TST-0002 | `src/opencl/raw/opencl-raw-api.ads` (`clCreateContext`, `clCreateCommandQueue`, `clCreateBuffer`, `clEnqueueWriteBuffer`, `clEnqueueReadBuffer`, `clFinish`) | `docs/VV/Execution_Logs/GATES/G2/rerun_01/G2_Report.md` (build) | PASS |
| OCLW-REQ-0002 | Core/Thick wrappers for Contexts/Queues/Buffers | Inspection + test | OCLW-TST-0002 | `src/opencl/core/opencl-core-contexts.*`, `src/opencl/core/opencl-core-queues.*`, `src/opencl/core/opencl-core-buffers.*` | `docs/VV/Execution_Logs/GATES/G2/rerun_01/G2_Report.md` (smoke_buffer_roundtrip run) | PASS |
| OCLW-REQ-0005 | Explicit status-based error flow for create/release/read/write/finish | Test | OCLW-TST-0002 | `src/opencl/core/opencl-core-contexts.adb`, `src/opencl/core/opencl-core-queues.adb`, `src/opencl/core/opencl-core-buffers.adb`, `tests/smoke/smoke_buffer_roundtrip.adb` | `docs/VV/Execution_Logs/GATES/G2/rerun_01/G2_Report.md` | PASS |
| OCLW-REQ-0008 | Explicit resource lifecycle for context/queue/buffer | Test | OCLW-TST-0002 | `tests/smoke/smoke_buffer_roundtrip.adb` (create/write/read/release reverse order) | `docs/VV/Execution_Logs/GATES/G2/rerun_01/G2_Report.md` (`RESULT=PASS`) | PASS |
| OCLW-REQ-0010 | Traceability maintained through Gate G2 closure artifacts | Inspection | OCLW-TST-0001, OCLW-TST-0002 | This document + closure + HW fingerprint | `docs/VV/Execution_Logs/GATES/G2/Closure.md`, `docs/HW/Platform_Fingerprint.md` | PASS |

## G3 Addendum (Program/Kernel Build + NDRange)

Primary gate evidence:
- `docs/VV/Execution_Logs/GATES/G3/rerun_05/G3_Report.md`
- `docs/VV/Execution_Logs/GATES/G3/Closure.md`

Capabilities under G3 scope:
- Programs/Kernels API + build diagnostics (`Build_Log` and related telemetry)
- Validation test: `tests/smoke/smoke_kernel_add1.adb`

| Requirement ID | Requirement focus | Verification method | Test ID | Implementation mapping | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| OCLW-REQ-0001 | Thin FFI expansion for program/kernel host API (`clCreateProgramWithSource`, `clBuildProgram`, `clGetProgramBuildInfo`, `clCreateKernel`, `clSetKernelArg`, `clEnqueueNDRangeKernel`) | Inspection + build | OCLW-TST-0002 | `src/opencl/raw/opencl-raw-api.ads` | `docs/VV/Execution_Logs/GATES/G3/rerun_05/G3_Report.md` (build + run via harness) | PASS |
| OCLW-REQ-0002 | Thick wrappers for program build diagnostics and kernel execution | Inspection + test | OCLW-TST-0002 | `src/opencl/core/opencl-core-programs.ads`, `src/opencl/core/opencl-core-programs.adb`, `src/opencl/core/opencl-core-kernels.ads`, `src/opencl/core/opencl-core-kernels.adb` | `docs/VV/Execution_Logs/GATES/G3/rerun_05/G3_Report.md` (`smoke_kernel_add1` path) | PASS |
| OCLW-REQ-0005 | Status-based error handling plus build diagnostics (`BUILD_STATUS`, options, log bytes, bounded log, source head) | Test | OCLW-TST-0002 | `tests/smoke/smoke_kernel_add1.adb`, `src/opencl/core/opencl-core-programs.adb` | `docs/VV/Execution_Logs/GATES/G3/rerun_05/G3_Report.md` (diagnostic output) | PASS |
| OCLW-REQ-0008 | Kernel lifecycle and execution flow (create/set args/enqueue/finish/read/verify) | Test | OCLW-TST-0002 | `tests/smoke/smoke_kernel_add1.adb` | `docs/VV/Execution_Logs/GATES/G3/rerun_05/G3_Report.md` (`RESULT=PASS`) | PASS |
| OCLW-REQ-0010 | End-to-end traceability kept through Gate G3 closure artifacts | Inspection | OCLW-TST-0001, OCLW-TST-0002 | This document + G3 closure + harness behavior | `docs/VV/Execution_Logs/GATES/G3/Closure.md`, `tools/run_smoke.sh` | PASS |

## G4 Addendum (Program Binaries / no-JIT preliminar)

Primary gate evidence:
- `docs/VV/Execution_Logs/GATES/G4/verify_03/G4_Verification_Report.md`
- `docs/VV/Execution_Logs/GATES/G4/Closure.md`

Capabilities under G4 scope:
- Raw constants: `CL_PROGRAM_BINARY_SIZES`, `CL_PROGRAM_BINARIES`
- Raw API: `clCreateProgramWithBinary` (plus `clGetProgramInfo` para path de binarios)
- Thick APIs: `Programs.Binary_Size`, `Programs.Get_Binary`, `Programs.Create_From_Binary`
- Validation test: `tests/smoke/smoke_program_binary_roundtrip.adb`
- Verification evidence: `docs/VV/Execution_Logs/GATES/G4/verify_03/G4_Verification_Report.md`

| Requirement ID | Requirement focus | Verification method | Test ID | Implementation mapping | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| OCLW-REQ-0001 | Thin FFI support for program binary introspection/loading path | Inspection + build | OCLW-TST-0002 | `src/opencl/raw/opencl-raw-api.ads` (`CL_PROGRAM_BINARY_SIZES`, `CL_PROGRAM_BINARIES`, `clGetProgramInfo`, `clCreateProgramWithBinary`) | `docs/VV/Execution_Logs/GATES/G4/verify_03/G4_Verification_Report.md` (checklist B PASS) | PASS |
| OCLW-REQ-0002 | Thick wrappers for binary size extraction, binary retrieval and program creation from binary | Inspection + test | OCLW-TST-0002 | `src/opencl/core/opencl-core-programs.ads`, `src/opencl/core/opencl-core-programs.adb` (`Binary_Size`, `Get_Binary`, `Create_From_Binary`) | `docs/VV/Execution_Logs/GATES/G4/verify_03/G4_Verification_Report.md` (checklist C PASS) | PASS |
| OCLW-REQ-0005 | Explicit status-based handling over binary roundtrip path | Test | OCLW-TST-0002 | `tests/smoke/smoke_program_binary_roundtrip.adb`, `src/opencl/core/opencl-core-programs.adb` | `docs/VV/Execution_Logs/GATES/G4/verify_03/03_run_smoke.log`, `docs/VV/Execution_Logs/GATES/G4/verify_03/04_extracts.log` (`RESULT=PASS`, `binary_size`, `binary_fnv1a32`) | PASS |
| OCLW-REQ-0010 | Gate-level traceability and evidence closure for G4 | Inspection | OCLW-TST-0001, OCLW-TST-0002 | This document + closure artifact | `docs/VV/Execution_Logs/GATES/G4/Closure.md`, `docs/VV/Execution_Logs/GATES/G4/verify_03/G4_Verification_Report.md` | PASS |

## G5 Addendum (RT Kernel Pack / strict no-JIT path)

Primary gate evidence:
- `docs/VV/Execution_Logs/GATES/G5/rerun_01/G5_Report.md`
- `docs/VV/Execution_Logs/GATES/G5/Closure.md`

Capabilities under G5 scope:
- Kernel Pack artifact: `manifest.kpack` + `program.bin`
- Fingerprint verification for platform/device/driver (strict match)
- Binary integrity verification via `binary_size` + `binary_fnv1a32`
- RT no-JIT path (RT smoke uses binary-load path only)
- Validation tests: `tests/smoke/gen_pack_add1.adb`, `tests/smoke/smoke_rt_load_pack_add1.adb`

| Requirement ID | Requirement focus | Verification method | Test ID | Implementation mapping | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| OCLW-REQ-0002 | RT APIs for pack parsing, hash verification and binary load workflow | Inspection + test | OCLW-TST-0002 | `src/opencl/rt/opencl-rt-packs.ads`, `src/opencl/rt/opencl-rt-loader.ads`, `src/opencl/rt/opencl-rt-hash.ads`, `tests/smoke/gen_pack_add1.adb`, `tests/smoke/smoke_rt_load_pack_add1.adb` | `docs/VV/Execution_Logs/GATES/G5/rerun_01/G5_Report.md` (`gen_pack_add1` and `smoke_rt_load_pack_add1` PASS) | PASS |
| OCLW-REQ-0005 | Fail-closed status behavior for hash/fingerprint mismatch in RT load path | Test | OCLW-TST-0002 | `tests/smoke/smoke_rt_load_pack_add1.adb`, `src/opencl/rt/opencl-rt-loader.adb`, `src/opencl/rt/opencl-rt-packs.adb` | `docs/VV/Execution_Logs/GATES/G5/rerun_01/G5_Report.md` (`negative_fingerprint_check=PASS`) | PASS |
| OCLW-REQ-0008 | Controlled lifecycle for offline pack generation and RT-only pack loading | Test | OCLW-TST-0002 | `tests/smoke/gen_pack_add1.adb`, `tests/smoke/smoke_rt_load_pack_add1.adb`, `tools/run_smoke.sh` | `docs/VV/Execution_Logs/GATES/G5/rerun_01/G5_Report.md` (`pack_dir`, `binary_size`, `binary_fnv1a32`, run exit code 0) | PASS |
| OCLW-REQ-0010 | Traceability closure for Gate G5 evidence and QA closeout | Inspection | OCLW-TST-0001, OCLW-TST-0002 | This document + closure artifact | `docs/VV/Execution_Logs/GATES/G5/Closure.md`, `docs/VV/Execution_Logs/GATES/G5/rerun_01/G5_Report.md` | PASS |

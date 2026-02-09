# G3 Report

- UTC timestamp: 2026-02-09T22:36:16Z
- git rev-parse HEAD: e4733c80f050451b9b658a8e69d02637875de394

## Build

Command: `gprbuild -P tests/tests.gpr`
Exit code: 0

```text
gprbuild: "smoke_platforms" up to date
gprbuild: "smoke_core" up to date
gprbuild: "smoke_buffer_roundtrip" up to date
gprbuild: "smoke_kernel_add1" up to date
```

## Runs

### ./tests/bin/smoke_platforms
Exit code: 0

```text
platform_count_reported= 1
platform_count_used= 1
Platform[ 0]
  name    : Portable Computing Language
  vendor  : The pocl project
  version : OpenCL 3.0 PoCL 5.0+debian  Linux, None+Asserts, RELOC, SPIR, LLVM 16.0.6, SLEEF, DISTRO, POCL_DEBUG
  device_count_reported= 1
  device_count_used= 1
  Device[ 0]
    name    : cpu-haswell-Intel(R) Core(TM) i5-14600K
    vendor  : GenuineIntel
    driver  : 5.0+debian
    version : OpenCL 3.0 PoCL HSTR: cpu-x86_64-pc-linux-gnu-haswell
    type    : 2
```

### ./tests/bin/smoke_core
Exit code: 0

```text
platform_capacity= 16
platform_count_used= 1
Platform[ 0]
  name    : Portable Computing Language
  vendor  : The pocl project
  version : OpenCL 3.0 PoCL 5.0+debian  Linux, None+Asserts, RELOC, SPIR, LLVM 16.0.6, SLEEF, DISTRO, POCL_DEBUG
  device_capacity= 64
  device_count_used= 1
  Device[ 0]
    name    : cpu-haswell-Intel(R) Core(TM) i5-14600K
    vendor  : GenuineIntel
    version : OpenCL 3.0 PoCL HSTR: cpu-x86_64-pc-linux-gnu-haswell
    driver  : 5.0+debian
```

### ./tests/bin/smoke_buffer_roundtrip
Exit code: 0

```text
RESULT=PASS
```

### ./tests/bin/smoke_kernel_add1
Exit code: 1

```text
INFO device_opencl_c_version=OpenCL C 1.2 PoCL
INFO build_retry first_status=CL_BUILD_PROGRAM_FAILURE status_int=-11 retry_options=-cl-std=CL1.2
ERROR build_program: CL_BUILD_PROGRAM_FAILURE status_int=-11
BUILD_STATUS=CL_BUILD_ERROR
build_options_bytes_reported=14
BUILD_OPTIONS=-cl-std=CL1.2
build_log_bytes_reported=76
BUILD_LOG_BEGIN
Device cpu-haswell-Intel(R) Core(TM) i5-14600K failed to build the program

BUILD_LOG_END
PROGRAM_SOURCE_HEAD_BEGIN
__kernel void add1(__global const uchar* src, __global uchar* dst) { const size_t gid = get_global_id(0); dst[gid] = (uchar)(src[gid] + (uchar)1); }
PROGRAM_SOURCE_HEAD_END
RESULT=FAIL
```

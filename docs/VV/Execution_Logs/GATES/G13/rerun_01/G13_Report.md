# Gate G13 Rerun 01 Report

- UTC timestamp: 2026-02-18T22:47:27Z
- git HEAD: 1d7acd3ad94d580249f0a9444940ddb706c2d858

## Fingerprint (platform/device/driver)
- Source: `docs/VV/Execution_Logs/GATES/G13/rerun_01/03_extracts.log`

```text
platform_count_used= 1
  name    : Portable Computing Language
  vendor  : The pocl project
  version : OpenCL 3.0 PoCL 5.0+debian  Linux, None+Asserts, RELOC, SPIR, LLVM 16.0.6, SLEEF, DISTRO, POCL_DEBUG
  Device[ 0]
    name    : cpu-haswell-Intel(R) Core(TM) i5-14600K
    vendor  : GenuineIntel
    version : OpenCL 3.0 PoCL HSTR: cpu-x86_64-pc-linux-gnu-haswell
    driver  : 5.0+debian
smoke_core_exit_code=0
```

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- stdout+stderr: `docs/VV/Execution_Logs/GATES/G13/rerun_01/01_build.log`

## Run
- Command: `tools/run_smoke.sh`
- Exit code: 0
- stdout+stderr: `docs/VV/Execution_Logs/GATES/G13/rerun_01/02_run_smoke.log`

## Bench Extract
- RESULT=PASS
- INFO host_ns_p50=329550
- INFO host_ns_p99=757788
- INFO device_ns_p50=83949
- INFO device_ns_p99=408960
- Extract log: `docs/VV/Execution_Logs/GATES/G13/rerun_01/03_extracts.log`

## Final Result
- PASS

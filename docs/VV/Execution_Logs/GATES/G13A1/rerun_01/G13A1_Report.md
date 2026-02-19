# G13A1 Report

- Timestamp UTC: 2026-02-18T23:33:42Z
- Git HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Fingerprint (platform/device/driver)
```text
  name    : Portable Computing Language
  vendor  : The pocl project
  version : OpenCL 3.0 PoCL 5.0+debian  Linux, None+Asserts, RELOC, SPIR, LLVM 16.0.6, SLEEF, DISTRO, POCL_DEBUG
    name    : cpu-haswell-Intel(R) Core(TM) i5-14600K
    vendor  : GenuineIntel
    driver  : 5.0+debian
    version : OpenCL 3.0 PoCL HSTR: cpu-x86_64-pc-linux-gnu-haswell
  name    : Portable Computing Language
  vendor  : The pocl project
  version : OpenCL 3.0 PoCL 5.0+debian  Linux, None+Asserts, RELOC, SPIR, LLVM 16.0.6, SLEEF, DISTRO, POCL_DEBUG
    name    : cpu-haswell-Intel(R) Core(TM) i5-14600K
    vendor  : GenuineIntel
    version : OpenCL 3.0 PoCL HSTR: cpu-x86_64-pc-linux-gnu-haswell
    driver  : 5.0+debian
```

## Build
- Command: gprbuild -P tests/tests.gpr
- Exit code: 0
- Log: docs/VV/Execution_Logs/GATES/G13A1/rerun_01/01_build.log

## Run
- Command: tools/run_smoke.sh
- Exit code: 0
- Log: docs/VV/Execution_Logs/GATES/G13A1/rerun_01/02_run_smoke.log

## Bench Extract (bench_rt_pack_add1)
- Extract log: docs/VV/Execution_Logs/GATES/G13A1/rerun_01/03_extracts.log
```text
RESULT=PASS
INFO init_ns=4131159
INFO exec_host_ns_p50=268378
INFO exec_host_ns_p99=461690
INFO exec_dev_ns_p50=82842
INFO exec_dev_ns_p99=254238
INFO profiling=AVAILABLE
bench_rt_pack_add1_exit_code=0
```

## Final Result
- PASS

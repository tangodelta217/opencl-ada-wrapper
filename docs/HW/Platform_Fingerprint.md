# Platform Fingerprint (Development ICD)

- UTC date: 2026-02-09T19:04:18Z
- Commit: `ec60900b5e7fe754e5610d9270de51c13781dcaa`
- Source evidence: `docs/VV/Execution_Logs/GATES/G2/rerun_01/G2_Report.md`

## OpenCL Platform

- Platform Name: Portable Computing Language
- Platform Vendor: The pocl project
- Platform Version: OpenCL 3.0 PoCL 5.0+debian  Linux, None+Asserts, RELOC, SPIR, LLVM 16.0.6, SLEEF, DISTRO, POCL_DEBUG

## OpenCL Device

- Device Name: cpu-haswell-Intel(R) Core(TM) i5-14600K
- Device Vendor: GenuineIntel
- Driver Version: 5.0+debian
- Device Version: OpenCL 3.0 PoCL HSTR: cpu-x86_64-pc-linux-gnu-haswell

## Regeneration

Run these commands from repository root:

```bash
./tests/bin/smoke_platforms
./tests/bin/smoke_core
```

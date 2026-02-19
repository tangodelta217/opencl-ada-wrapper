# G14 Rerun 02 Report (Subdevices)

- UTC timestamp: 2026-02-19T08:22:16Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G14/rerun_02/01_build.log`

## Run
- Command: `tools/run_smoke.sh`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G14/rerun_02/02_run_smoke.log`

## Extracts (smoke_program_binaries_subdevices)
- Source: `docs/VV/Execution_Logs/GATES/G14/rerun_02/03_extracts.log`
- RESULT: RESULT=SKIP reason=num_devices_not_2
- num_devices: INFO num_devices=1
- binary_size_0: INFO binary_size_0=0
- binary_size_1: INFO binary_size_1=0

```text
== smoke_program_binaries_subdevices ==
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_program_binaries_subdevices
INFO num_devices=1
INFO binary_size_0=0
INFO binary_size_1=0
RESULT=SKIP reason=num_devices_not_2
smoke_program_binaries_subdevices_exit_code=0
```

## Final
- Build status: PASS
- Run status: PASS

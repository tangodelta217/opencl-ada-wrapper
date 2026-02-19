# G22 Report (Backfill rerun_01)

- UTC timestamp: 2026-02-19T10:38:44Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G22/rerun_01/01_build.log`

## Run
- Exit code: 0
- Missing executables: 0
- Log: `docs/VV/Execution_Logs/GATES/G22/rerun_01/02_run.log`

## Extracts
- Source: `docs/VV/Execution_Logs/GATES/G22/rerun_01/03_extracts.log`

```text
$ ./tests/bin/smoke_rt_build_options_policy 
INFO pack_dir=docs/VV/Execution_Logs/local/pack_rt_build_options_policy
INFO manifest_path=docs/VV/Execution_Logs/local/pack_rt_build_options_policy/manifest.kpack
INFO binary_path=docs/VV/Execution_Logs/local/pack_rt_build_options_policy/program.bin
INFO gen_pack_add1_return_code=0 log=docs/VV/Execution_Logs/local/pack_rt_build_options_policy/gen_pack_add1.log
INFO case_allow=PASS
INFO case_deny=PASS expected=OCLW_BUILD_OPTIONS_DISALLOWED
RESULT=PASS
smoke_rt_build_options_policy_exit_code=0
run_exit_code=0
```

## Final
- RESULT=PASS
- Reason=result_pass

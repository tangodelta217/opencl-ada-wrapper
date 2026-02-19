# G33 Report

- UTC timestamp: 2026-02-19T18:12:53Z
- git HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build

- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G33/rerun_01/01_build.log`

## Run

- Command: `tools/run_smoke.sh`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G33/rerun_01/02_run_smoke.log`

## Extract (smoke_rt_plugin_allowlist_policy)

- RESULT: RESULT=PASS
- Exit line: smoke_rt_plugin_allowlist_policy_exit_code=0
- INFO case_not_allowed=PASS expected=OCLW_PLUGIN_PATH_NOT_ALLOWED got=OCLW_PLUGIN_PATH_NOT_ALLOWED
- INFO case_allowed=PASS
- INFO case_symlink=PASS expected=OCLW_FS_POLICY_VIOLATION got=OCLW_FS_POLICY_VIOLATION
- INFO case_world_writable=PASS expected=OCLW_PLUGIN_UNSAFE_PERMS got=OCLW_PLUGIN_UNSAFE_PERMS

## Raw Extract

- File: `docs/VV/Execution_Logs/GATES/G33/rerun_01/03_extracts.log`

```txt
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_plugin_allowlist_policy
INFO plugin_build_return_code=0 log=/tmp/oclw_g33_plugin_allowlist_policy/plugin_build.log
INFO strict_policy_mode=ENABLED
INFO plugin_path=/home/tangodelta/opencl-ada-wrapper/tools/crypto_provider_ref/liboclw_crypto_provider_ref.so
INFO case_not_allowed=PASS expected=OCLW_PLUGIN_PATH_NOT_ALLOWED got=OCLW_PLUGIN_PATH_NOT_ALLOWED
INFO case_allowed=PASS
INFO case_symlink=PASS expected=OCLW_FS_POLICY_VIOLATION got=OCLW_FS_POLICY_VIOLATION
INFO case_world_writable=PASS expected=OCLW_PLUGIN_UNSAFE_PERMS got=OCLW_PLUGIN_UNSAFE_PERMS
RESULT=PASS
smoke_rt_plugin_allowlist_policy_exit_code=0
```

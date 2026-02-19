# Gate G31 Report (rerun_01)

- UTC timestamp: 2026-02-19T12:24:05Z
- git HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: gprbuild -P tests/tests.gpr
- Exit code: 0
- Log: docs/VV/Execution_Logs/GATES/G31/rerun_01/01_build.log

## Run
- Command: tools/run_smoke.sh
- Exit code: 0
- Log: docs/VV/Execution_Logs/GATES/G31/rerun_01/02_run_smoke.log

## Extract: smoke_rt_pack_symlink_escape
- RESULT smoke_rt_pack_symlink_escape: PASS

### INFO/RESULT lines
```text
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_pack_symlink_escape
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T122412Z_kpack_add1/g31_symlink_escape
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T122412Z_kpack_add1/g31_symlink_escape
RESULT=PASS
INFO case_manifest_symlink=PASS expected=OCLW_FS_POLICY_VIOLATION got=OCLW_FS_POLICY_VIOLATION
INFO case_binary_symlink=PASS expected=OCLW_FS_POLICY_VIOLATION got=OCLW_FS_POLICY_VIOLATION
RESULT=PASS
smoke_rt_pack_symlink_escape_exit_code=0
```

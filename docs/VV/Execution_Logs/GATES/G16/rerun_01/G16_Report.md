# Gate G16 Hardening Report

- UTC: 2026-02-19T01:17:02Z
- git HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G16/rerun_01/01_build.log`

## Run Smoke
- Command: `tools/run_smoke.sh`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G16/rerun_01/02_run_smoke.log`

## Extracts
- Extract log: `docs/VV/Execution_Logs/GATES/G16/rerun_01/03_extracts.log`

### smoke_constant_time_compare
```text
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_constant_time_compare
INFO bytes_equal=PASS
INFO bytes_not_equal=PASS
INFO bytes_len_mismatch=PASS
INFO string_equal=PASS
INFO string_not_equal=PASS
INFO string_len_mismatch=PASS
RESULT=PASS
smoke_constant_time_compare_exit_code=0

```

### smoke_rt_negative_cases (limits)
```text
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_negative_cases
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T011642Z_kpack_add1
INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T011642Z_kpack_add1/manifest.kpack
INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T011642Z_kpack_add1/program.bin
INFO case1_binary_tamper=PASS expected=OCLW_HASH_MISMATCH
INFO case2_fingerprint_tamper=PASS expected=OCLW_FINGERPRINT_MISMATCH
INFO case3_format_tamper=PASS expected=OCLW_PACK_FORMAT_ERROR
INFO case4_line_limit=PASS expected=OCLW_PACK_FORMAT_ERROR
RESULT=PASS
smoke_rt_negative_cases_exit_code=0
```

## Final Result
PASS

# Gate G9 Rerun 01 Report

- UTC timestamp: 2026-02-18T18:30:54Z
- git HEAD: 581c42ba2125e454a5504751958663a5cd841787

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- stdout+stderr: `docs/VV/Execution_Logs/GATES/G9/rerun_01/01_build.log`

## Run
- Command: `tools/run_smoke.sh`
- Exit code: 0
- stdout+stderr: `docs/VV/Execution_Logs/GATES/G9/rerun_01/02_run_smoke.log`

## Extract
- `smoke_rt_strict_policy`: RESULT=PASS

## Evidence
- `docs/VV/Execution_Logs/GATES/G9/rerun_01/03_extracts.log`

```text
# G9 Extracts
build_exit_code=0
run_exit_code=0
smoke_rt_strict_policy_result=RESULT=PASS

## smoke_rt_strict_policy block
160:$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_strict_policy
161:INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T183055Z_kpack_add1
162:INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T183055Z_kpack_add1/manifest.kpack
163:INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T183055Z_kpack_add1/program.bin
164:INFO strict_policy_mode=ENABLED
165:INFO verifier_mode=REFERENCE_PLUGIN (NOT CRYPTO)
166:INFO gen_pack_add1_return_code=0 log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T183055Z_kpack_add1/gen_pack_add1.log
167:INFO plugin_build_return_code=0 log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T183055Z_kpack_add1/crypto_plugin_build.log
168:INFO case1=PASS expected=OCLW_SIGNATURE_MISSING
169:INFO case2=PASS expected=OCLW_SIGNATURE_DISALLOWED|OCLW_SIGNATURE_INVALID
170:INFO case3=PASS
171:RESULT=PASS
172:smoke_rt_strict_policy_exit_code=0
```

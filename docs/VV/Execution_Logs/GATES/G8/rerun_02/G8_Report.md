# Gate G8 Rerun 02 Report

- UTC timestamp: 2026-02-18T18:20:40Z
- git HEAD: 581c42ba2125e454a5504751958663a5cd841787

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- stdout+stderr: `docs/VV/Execution_Logs/GATES/G8/rerun_02/01_build.log`

## Run
- Command: `tools/run_smoke.sh`
- Exit code: 0
- stdout+stderr: `docs/VV/Execution_Logs/GATES/G8/rerun_02/02_run_smoke.log`

## Requested Results
- `smoke_rt_signature_enforcement`: RESULT=PASS
- `smoke_rt_signature_plugin`: RESULT=PASS

## Extract Evidence
- `docs/VV/Execution_Logs/GATES/G8/rerun_02/03_extracts.log`

```text
# G8 rerun_02 extracts
build_exit_code=0
run_exit_code=0
smoke_rt_signature_enforcement_result=RESULT=PASS
smoke_rt_signature_plugin_result=RESULT=PASS

## smoke_rt_signature_enforcement block
135:$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_signature_enforcement
136:INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T182040Z_kpack_add1
137:INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T182040Z_kpack_add1/manifest.kpack
138:INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T182040Z_kpack_add1/program.bin
139:INFO verifier_mode=TEST-FNV1A32 (NOT CRYPTO)
140:INFO gen_pack_add1_return_code=0 log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T182040Z_kpack_add1/gen_pack_add1.log
141:INFO caseA=PASS expected=OCLW_SIGNATURE_NOT_IMPLEMENTED
142:INFO caseB=PASS
143:RESULT=PASS
144:smoke_rt_signature_enforcement_exit_code=0

## smoke_rt_signature_plugin block
145:$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_signature_plugin
146:INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T182040Z_kpack_add1
147:INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T182040Z_kpack_add1/manifest.kpack
148:INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T182040Z_kpack_add1/program.bin
149:INFO verifier_mode=REFERENCE_PLUGIN (NOT CRYPTO)
150:INFO plugin_build_return_code=0 log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T182040Z_kpack_add1/crypto_plugin_build.log
151:INFO gen_pack_add1_return_code=0 log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T182040Z_kpack_add1/gen_pack_add1.log
152:INFO oclw_crypto_plugin=/home/tangodelta/opencl-ada-wrapper/tools/crypto_provider_ref/liboclw_crypto_provider_ref.so
153:INFO oclw_crypto_symbol=oclw_kpack_verify_v1
154:INFO positive_case=PASS
155:INFO negative_case=PASS expected=OCLW_SIGNATURE_INVALID
156:RESULT=PASS
157:smoke_rt_signature_plugin_exit_code=0
```

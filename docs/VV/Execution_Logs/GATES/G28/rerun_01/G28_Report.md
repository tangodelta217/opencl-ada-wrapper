# G28 Report (Backfill rerun_01)

- UTC timestamp: 2026-02-19T10:38:44Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G28/rerun_01/01_build.log`

## Run
- Exit code: 0
- Missing executables: 0
- Log: `docs/VV/Execution_Logs/GATES/G28/rerun_01/02_run.log`

## Extracts
- Source: `docs/VV/Execution_Logs/GATES/G28/rerun_01/03_extracts.log`

```text
$ ./tools/crypto_provider_ref/build.sh 
crypto_provider_ref_build_exit_code=0
$ env OCLW_CRYPTO_PLUGIN=/home/tangodelta/opencl-ada-wrapper/tools/crypto_provider_ref/liboclw_crypto_provider_ref.so OCLW_CRYPTO_SYMBOL=oclw_kpack_verify_v1 ./tests/bin/smoke_crypto_provider_conformance
INFO plugin_path=/home/tangodelta/opencl-ada-wrapper/tools/crypto_provider_ref/liboclw_crypto_provider_ref.so
INFO plugin_symbol=oclw_kpack_verify_v1
INFO case_valid_signature=PASS expected=CL_SUCCESS
INFO case_invalid_signature=PASS expected=OCLW_SIGNATURE_INVALID
INFO case_unknown_alg=PASS expected=OCLW_SIGNATURE_INVALID
RESULT=PASS
smoke_crypto_provider_conformance_exit_code=0
run_exit_code=0
```

## Final
- RESULT=PASS
- Reason=result_pass

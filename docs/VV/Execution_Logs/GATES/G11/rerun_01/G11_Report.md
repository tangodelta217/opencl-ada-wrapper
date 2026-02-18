# Gate G11 Rerun 01 Report

- UTC timestamp: 2026-02-18T20:30:46Z
- git HEAD: 77fd6d48a7859c02b2e1dc96834d57e3670edd11

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- stdout+stderr: `docs/VV/Execution_Logs/GATES/G11/rerun_01/01_build.log`

## Run Smoke
- Command: `tools/run_smoke.sh`
- Exit code: 0
- stdout+stderr: `docs/VV/Execution_Logs/GATES/G11/rerun_01/02_run_smoke.log`

## Run Packaging
- Command: `tools/package_rt_bundle.sh`
- Exit code: 0
- stdout+stderr: `docs/VV/Execution_Logs/GATES/G11/rerun_01/03_package_bundle.log`

## Bundle Evidence
- Archive path: `/home/tangodelta/opencl-ada-wrapper/dist/oclw_rt_bundle_20260218T203050Z.tar.gz`
- Evidence log: `docs/VV/Execution_Logs/GATES/G11/rerun_01/04_bundle_evidence.log`

`tar -tzf` top 50 lines:

```text
bundle_archive=/home/tangodelta/opencl-ada-wrapper/dist/oclw_rt_bundle_20260218T203050Z.tar.gz
tar_list_top50_start
oclw_rt_bundle_20260218T203050Z/
oclw_rt_bundle_20260218T203050Z/docs/
oclw_rt_bundle_20260218T203050Z/docs/OPS/
oclw_rt_bundle_20260218T203050Z/docs/OPS/RT_Deployment_Guide.md
oclw_rt_bundle_20260218T203050Z/docs/CM/
oclw_rt_bundle_20260218T203050Z/docs/CM/SBOM_Minimal.md
oclw_rt_bundle_20260218T203050Z/docs/CM/Delivery_Content.md
oclw_rt_bundle_20260218T203050Z/docs/ARCH/
oclw_rt_bundle_20260218T203050Z/docs/ARCH/Crypto_Plugin_C_ABI_Contract.md
oclw_rt_bundle_20260218T203050Z/logs/
oclw_rt_bundle_20260218T203050Z/logs/gen_pack_add1.log
oclw_rt_bundle_20260218T203050Z/logs/build_tests.log
oclw_rt_bundle_20260218T203050Z/logs/build_opencl_wrapper.log
oclw_rt_bundle_20260218T203050Z/example_pack/
oclw_rt_bundle_20260218T203050Z/example_pack/manifest.kpack
oclw_rt_bundle_20260218T203050Z/example_pack/program.bin
oclw_rt_bundle_20260218T203050Z/CHECKSUMS.sha256
oclw_rt_bundle_20260218T203050Z/BUNDLE_INFO.txt
tar_list_top50_end
tar_rc=0
```

## Final Result
- PASS

# G32 Report

- UTC: 2026-02-19T16:21:54Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37
- Build command: gprbuild -P tests/tests.gpr
- Build exit code: 0
- Build log: docs/VV/Execution_Logs/GATES/G32/rerun_01/01_build.log
- Run command: tools/run_smoke.sh
- Run exit code: 0
- Run log: docs/VV/Execution_Logs/GATES/G32/rerun_01/02_run_smoke.log

## Extract

- smoke_rt_toctou_manifest_swap: RESULT=PASS
- smoke_rt_toctou_binary_swap: RESULT=PASS

### INFO expected lines

- INFO case_manifest_toctou=PASS expected=OCLW_FS_TOCTOU_DETECTED got=OCLW_FS_TOCTOU_DETECTED got_int=-32023
- INFO case_binary_toctou=PASS expected=OCLW_FS_TOCTOU_DETECTED got=OCLW_FS_TOCTOU_DETECTED got_int=-32023

### Smoke exit lines

- smoke_rt_toctou_manifest_swap_exit_code=0
- smoke_rt_toctou_binary_swap_exit_code=0

## Raw extracts

- docs/VV/Execution_Logs/GATES/G32/rerun_01/03_extracts.log

```txt
# Extracts G32

## smoke_rt_toctou_manifest_swap
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_toctou_manifest_swap
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T162046Z_kpack_add1/g32_manifest_toctou
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T162046Z_kpack_add1/g32_manifest_toctou
INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T162046Z_kpack_add1/g32_manifest_toctou/manifest.kpack
INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T162046Z_kpack_add1/g32_manifest_toctou/program.bin
INFO binary_size=48617
INFO binary_fnv1a32=1003753064
RESULT=PASS
INFO gen_pack_add1_return_code=0
INFO case_manifest_toctou=PASS expected=OCLW_FS_TOCTOU_DETECTED got=OCLW_FS_TOCTOU_DETECTED got_int=-32023
RESULT=PASS
smoke_rt_toctou_manifest_swap_exit_code=0

## smoke_rt_toctou_binary_swap
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_toctou_binary_swap
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T162046Z_kpack_add1/g32_binary_toctou
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T162046Z_kpack_add1/g32_binary_toctou
INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T162046Z_kpack_add1/g32_binary_toctou/manifest.kpack
INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260219T162046Z_kpack_add1/g32_binary_toctou/program.bin
INFO binary_size=48617
INFO binary_fnv1a32=1988555955
RESULT=PASS
INFO gen_pack_add1_return_code=0
INFO case_binary_toctou=PASS expected=OCLW_FS_TOCTOU_DETECTED got=OCLW_FS_TOCTOU_DETECTED got_int=-32023
RESULT=PASS
smoke_rt_toctou_binary_swap_exit_code=0
```

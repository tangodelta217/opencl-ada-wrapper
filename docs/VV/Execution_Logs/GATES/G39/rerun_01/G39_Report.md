# Gate G39 Report

- UTC timestamp: 2026-02-20T02:31:50Z
- git HEAD: 374d9a880c9d58ead4e3bcda4beb588ef3956dcd

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G39/rerun_01/01_build.log`

## Run
- Command: `tools/run_smoke.sh`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G39/rerun_01/02_run_smoke.log`

## Extract: smoke_ew_mlp_inference
- Source: `docs/VV/Execution_Logs/GATES/G39/rerun_01/03_extracts.log`

### RESULT
12:RESULT=PASS
13:smoke_ew_mlp_inference_exit_code=0

### Accuracy
3:INFO accuracy=256/256

### Confusion Matrix
8:INFO confusion_row_0=64,0,0,0
9:INFO confusion_row_1=0,64,0,0
10:INFO confusion_row_2=0,0,64,0
11:INFO confusion_row_3=0,0,0,64

### Raw Block
```text
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_ew_mlp_inference
INFO batch=256
INFO accuracy=256/256
INFO logits_mismatches=0
INFO class_mismatches=0
INFO cpu_expected_mismatches=0
INFO class_out_of_range=0
INFO confusion_row_0=64,0,0,0
INFO confusion_row_1=0,64,0,0
INFO confusion_row_2=0,0,64,0
INFO confusion_row_3=0,0,0,64
RESULT=PASS
smoke_ew_mlp_inference_exit_code=0
```

# G26 Report (Backfill rerun_01)

- UTC timestamp: 2026-02-19T10:38:44Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G26/rerun_01/01_build.log`

## Run
- Exit code: 0
- Missing executables: 0
- Log: `docs/VV/Execution_Logs/GATES/G26/rerun_01/02_run.log`

## Extracts
- Source: `docs/VV/Execution_Logs/GATES/G26/rerun_01/03_extracts.log`

```text
$ ./tests/bin/bench_transfers_h2d_d2h 
INFO transfer_bytes=4194304
INFO warmup=5 iterations=40
INFO profiling=AVAILABLE
INFO write_host_ns_p50=188129
INFO write_host_ns_p99=400522
INFO read_host_ns_p50=163113
INFO read_host_ns_p99=508616
INFO write_dev_ns_p50=172485
INFO write_dev_ns_p99=379250
INFO read_dev_ns_p50=148326
INFO read_dev_ns_p99=494598
RESULT=PASS
bench_transfers_h2d_d2h_exit_code=0
$ ./tests/bin/bench_batching_add1 
INFO transfer_bytes=4096
INFO warmup_batches=2
INFO batches=30
INFO batch_iterations=16
INFO total_iterations=480
INFO throughput_iter_per_sec=8349
INFO batch_host_ns_p50=1806653
INFO batch_host_ns_p99=3019741
INFO profiling=AVAILABLE
INFO batch_dev_ns_p50=592723
INFO batch_dev_ns_p99=840397
RESULT=PASS
bench_batching_add1_exit_code=0
$ ./tools/crypto_provider_ref/build.sh 
crypto_provider_ref_build_exit_code=0
$ env OCLW_CRYPTO_PLUGIN=/home/tangodelta/opencl-ada-wrapper/tools/crypto_provider_ref/liboclw_crypto_provider_ref.so OCLW_CRYPTO_SYMBOL=oclw_kpack_verify_v1 ./tests/bin/bench_rt_pack_add1
INFO pack_dir=docs/VV/Execution_Logs/local/20260219T103907Z_bench_rt_pack
INFO warmup=10 iterations=200
INFO plugin_path=/home/tangodelta/opencl-ada-wrapper/tools/crypto_provider_ref/liboclw_crypto_provider_ref.so
INFO gen_pack_add1_return_code=0 log=docs/VV/Execution_Logs/local/20260219T103907Z_bench_rt_pack/bench_gen_pack_add1.log
INFO offline_pack_generated=1
INFO init_ns=2309285
INFO phase_verify_ns=448374
INFO phase_create_ctx_ns=699268
INFO phase_create_prog_ns=1157067
INFO phase_build_ns=1157067
INFO phase_build_ns_mode=INCLUDED_IN_CREATE_PROG
INFO phase_kernel_setup_ns=3612
INFO phase_exec_ns_p50=270614
INFO phase_exec_ns_p99=471127
INFO exec_host_ns_p50=270614
INFO exec_host_ns_p95=383126
INFO exec_host_ns_p99=471127
INFO profiling=AVAILABLE
INFO exec_dev_ns_p50=69465
INFO exec_dev_ns_p95=163054
INFO exec_dev_ns_p99=207784
INFO csv_path=docs/VV/Execution_Logs/local/20260219T103907Z_bench_rt_pack_add1.csv
RESULT=PASS
bench_rt_pack_add1_exit_code=0
run_exit_code=0
```

## Final
- RESULT=PASS
- Reason=result_pass

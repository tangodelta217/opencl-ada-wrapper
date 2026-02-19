# G25 Rerun 02 Report (Reproducible Bundle)

- UTC timestamp: 2026-02-19T10:35:20Z
- HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Build
- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0
- Log: `docs/VV/Execution_Logs/GATES/G25/rerun_02/01_build.log`

## Reproducible Packaging
- SOURCE_DATE_EPOCH: 1700000000
- Run 1 command: `OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH=1700000000 tools/package_rt_bundle.sh`
- Run 1 exit code: 0
- Run 1 log: `docs/VV/Execution_Logs/GATES/G25/rerun_02/02_package_run1.log`
- Run 2 command: `OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH=1700000000 tools/package_rt_bundle.sh`
- Run 2 exit code: 0
- Run 2 log: `docs/VV/Execution_Logs/GATES/G25/rerun_02/03_package_run2.log`

## Hash Comparison (SHA-256)
- archive: `dist/oclw_rt_bundle_reproducible.tar.gz`
- sha1: f6a2d90e10c33861ce906b61b55c51fda1267691b54c72c71c0a2d6befc16b15
- sha2: f6a2d90e10c33861ce906b61b55c51fda1267691b54c72c71c0a2d6befc16b15

## Result
- RESULT=PASS
- Rule: PASS if sha1==sha2.

## Evidence
- Compare log: `docs/VV/Execution_Logs/GATES/G25/rerun_02/04_compare_sha.log`

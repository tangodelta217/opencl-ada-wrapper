# G36 Test Seam Exclusion Report

- UTC timestamp: 2026-02-19T20:34:37Z
- git HEAD: bdac2e785fc1934bfad826572b8b397ac9e4cb37

## Scope
- Verify TOCTOU test seam is not present/usable in release artifact build.

## Commands Executed
1. gprbuild -P opencl_wrapper.gpr -p
2. gprbuild -P tests/tests.gpr
3. grep -R "Test_Seam" obj/ || true
4. find obj -name "*test*seam*" -o -name "*Test_Seam*" || true
5. grep -R "Test_Seam" tests/obj || true
6. find tests/obj -name "*test*seam*" -o -name "*Test_Seam*" || true

## Build
- Release build exit code: 0
- Release build log: docs/VV/Execution_Logs/GATES/G36/rerun_01/01_build_release.log
- Tests build exit code: 0
- Tests build log: docs/VV/Execution_Logs/GATES/G36/rerun_01/01b_build_tests.log

## Exclusion Checks
- Release obj grep matches (Test_Seam): 0
- Release obj find matches (*test*seam*/*Test_Seam*): 0
- Tests obj grep matches (Test_Seam): 3
- Tests obj find matches (*test*seam*/*Test_Seam*): 4
- Release scan log: docs/VV/Execution_Logs/GATES/G36/rerun_01/02_release_obj_seam_scan.log
- Tests scan log: docs/VV/Execution_Logs/GATES/G36/rerun_01/03_tests_obj_seam_scan.log

## Assessment
- PASS: no Test_Seam traces found in release obj/; seam remains observable only in tests/obj.

## Reinforcement Applied
- Public seam controls were removed from OpenCL.RT.FS public API and kept as private hooks for child test units only.
- ADR: docs/ARCH/ADR-0023-test-seam-release-exclusion.md

## Final
RESULT=PASS

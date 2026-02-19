# Smoke Test Design

## Scope
`tests/smoke/smoke_platforms.adb` validates OpenCL host enumeration via the thin
binding (`clGetPlatformIDs`, `clGetPlatformInfo`, `clGetDeviceIDs`,
`clGetDeviceInfo`).

## Safety Limits
The smoke test applies fixed limits to avoid unbounded stack reservations from
untrusted/defective driver-reported sizes:

- `Max_Platforms = 16`
- `Max_Devices_Per_Platform = 64`
- `Max_Info_Bytes = 4096`

Behavior when limits are exceeded:
- Platform/device counts are clamped and a warning is printed.
- Info-query byte sizes are clamped to `Max_Info_Bytes` and a warning is printed.

## Expected Cases
- No platforms:
  - `CL_PLATFORM_NOT_FOUND_KHR` is treated as expected and reported as
    `platform_count = 0`.
- No devices on a platform:
  - `CL_DEVICE_NOT_FOUND` is treated as expected and reported as
    `device_count = 0`.

## Deterministic Output for Regression
To make text regression stable across runs:
- Platforms are sorted by `(Vendor, Name)`.
- Devices are sorted by `(Vendor, Name)`.
- Sorting algorithm: bounded selection sort over fixed-size arrays.

## Logging
Recommended command for evidence capture:

`./bin/tests/smoke_platforms | tee docs/VV/Execution_Logs/<YYYY-MM-DD>_smoke_platforms.log`

## OCLW-TST-3001: `smoke_rt_pack_symlink_escape`
Purpose:
- Validate RT loader fail-closed behavior when `manifest.kpack` or `program.bin`
  is replaced by a symlink.

Preconditions:
- Test build is available (`gprbuild -P tests/tests.gpr`).
- Temporary writable path is available (typically `/tmp`).
- Filesystem supports symlink creation (if not, test may return `RESULT=SKIP`).

PASS criteria:
- Manifest symlink case is rejected with policy/status error.
- Binary symlink case is rejected with policy/status error.
- Final line is `RESULT=PASS`.

FAIL criteria:
- Any symlink case is accepted by RT load path.
- Final line is `RESULT=FAIL`.

Expected stable output:
- `INFO case_manifest_symlink=PASS expected=... got=...`
- `INFO case_binary_symlink=PASS expected=... got=...`
- `RESULT=PASS|FAIL|SKIP`

## OCLW-TST-3002: `smoke_rt_toctou_manifest_swap`
Purpose:
- Validate deterministic TOCTOU detection when `manifest.kpack` is swapped after
  pre-check and before the final read/use.

Preconditions:
- Test seam/hook for deterministic swap is enabled in test build.
- A valid baseline pack can be generated in a temporary path.

PASS criteria:
- TOCTOU swap is detected and returned as fail-closed status
  (`OCLW_FS_TOCTOU_DETECTED` or equivalent mapped status).
- Final line is `RESULT=PASS`.

FAIL criteria:
- Manifest swap is not detected and loader proceeds.
- Final line is `RESULT=FAIL`.

Expected stable output:
- `INFO case_manifest_toctou=PASS expected=OCLW_FS_TOCTOU_DETECTED got=...`
- `RESULT=PASS|FAIL|SKIP`

## OCLW-TST-3003: `smoke_rt_toctou_binary_swap`
Purpose:
- Validate deterministic TOCTOU detection when `program.bin` is swapped during
  the strict RT loading sequence.

Preconditions:
- Test seam/hook for deterministic swap is enabled in test build.
- A valid baseline pack can be generated in a temporary path.

PASS criteria:
- Binary swap is detected and returned as fail-closed status
  (`OCLW_FS_TOCTOU_DETECTED` or equivalent mapped status).
- Final line is `RESULT=PASS`.

FAIL criteria:
- Binary swap is not detected and loader proceeds.
- Final line is `RESULT=FAIL`.

Expected stable output:
- `INFO case_binary_toctou=PASS expected=OCLW_FS_TOCTOU_DETECTED got=...`
- `RESULT=PASS|FAIL|SKIP`

## OCLW-TST-3004: `smoke_rt_plugin_allowlist_policy`
Purpose:
- Validate RT strict plugin trust policy:
  allowlist enforcement, symlink rejection, and world-writable rejection.

Preconditions:
- Reference plugin can be built (`tools/crypto_provider_ref/build.sh`) or test
  handles unavailable toolchain as controlled `RESULT=SKIP`.
- Temporary writable path is available for negative permission cases.

PASS criteria:
- Case A: plugin outside allowlist -> rejected with `OCLW_PLUGIN_PATH_NOT_ALLOWED`.
- Case B: plugin inside allowlist -> accepted.
- Case C: plugin symlink -> rejected with FS/trust policy status.
- Case D: world-writable plugin -> rejected with `OCLW_PLUGIN_UNSAFE_PERMS`.
- Final line is `RESULT=PASS`.

FAIL criteria:
- Any negative case is accepted or status is inconsistent with policy.
- Final line is `RESULT=FAIL`.

Expected stable output:
- `INFO case_not_allowed=PASS expected=OCLW_PLUGIN_PATH_NOT_ALLOWED got=...`
- `INFO case_allowed=PASS`
- `INFO case_symlink=PASS expected=... got=...`
- `INFO case_world_writable=PASS expected=OCLW_PLUGIN_UNSAFE_PERMS got=...`
- `RESULT=PASS|FAIL|SKIP`

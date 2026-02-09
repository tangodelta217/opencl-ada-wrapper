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

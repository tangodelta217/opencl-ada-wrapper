# ADR-0003: Opaque Handle Mapping for Ada 2012 Compatibility

**Status:** Accepted
**Date:** 2026-02-09

## Context
The previous thin binding represented OpenCL handles as types derived from
`System.Address` with C representation items. This triggered Ada 2022-specific
restrictions in the current toolchain profile and failed the Ada 2012 build.

## Decision
- Replace Address-derived handle types with opaque pointer mappings:
  - `cl_platform_id_struct` and `cl_device_id_struct` as null C records.
  - `cl_platform_id` and `cl_device_id` as `access all` to those records.
- Apply `pragma Convention (C, ...)` to both opaque records and access types.
- Keep function imports unchanged at API surface level (`clGetPlatformIDs`,
  `clGetPlatformInfo`, `clGetDeviceIDs`, `clGetDeviceInfo`) while updating
  signatures to use the new pointer handle types.

## Rationale
- `access all <opaque_record>` maps directly to C opaque pointers and is
  compatible with Ada 2012.
- It avoids Ada 2022-only representation constraints encountered with
  Address-derived handle types.
- It preserves ABI intent while making calls safer and clearer (`null` for
  null handles/pointers).

## ABI Checks
The binding retains compile-time ABI checks (GNAT pragma) for critical scalar
sizes and pointer-size consistency:
- `cl_int = 32 bits`
- `cl_uint = 32 bits`
- `cl_ulong = 64 bits`
- `cl_platform_id` size equals `System.Address` size
- `cl_device_id` size equals `System.Address` size

## Impact
- Smoke test updated to initialize handle arrays with `null` instead of
  `System.Null_Address` casts.
- No expansion of OpenCL API scope beyond G0 needs.

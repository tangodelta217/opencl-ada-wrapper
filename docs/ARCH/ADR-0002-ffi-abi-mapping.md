# ADR-0002: OpenCL FFI ABI Mapping Hardening

**Status:** Accepted
**Date:** 2026-02-09

## Context
The OpenCL thin binding must remain ABI-safe across common data models, including
LP64 and LLP64 targets.

## Decision
- `cl_ulong` is mapped to `Interfaces.C.unsigned_long_long` to guarantee 64-bit
  width on LLP64 targets where C `unsigned long` may be 32-bit.
- `cl_bitfield` is based on the same 64-bit mapping through `cl_ulong`.
- Opaque handles (`cl_platform_id`, `cl_device_id`) are represented as
  `new System.Address` with `pragma Convention (C, ...)` to preserve pointer
  semantics and C call compatibility.
- GNAT compile-time checks (`pragma Compile_Time_Error`) enforce critical ABI
  assumptions for size and alignment.

## ABI Checks Applied
- `cl_int'Size = 32`
- `cl_uint'Size = 32`
- `cl_ulong'Size = 64`
- `cl_platform_id'Size = System.Address'Size`
- `cl_device_id'Size = System.Address'Size`
- `cl_platform_id'Alignment = System.Address'Alignment`
- `cl_device_id'Alignment = System.Address'Alignment`

## Consequences
- Binding fails fast at compile time when ABI assumptions are violated.
- Portability risk is reduced for mixed host toolchains/drivers.
- Scope remains minimal for G0: no additional OpenCL API surface is introduced.

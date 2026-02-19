# ADR-0023: Test Seam Exclusion from Release Artifacts

- **Date:** 2026-02-19
- **Status:** Accepted
- **Context:** G32 introduces deterministic TOCTOU negative tests using a seam
  hook around FS snapshot timing. IV&V release QA (G36) requires proving that
  this seam is not present/usable in release artifacts.

## Decision

1. `OpenCL.RT.FS` no longer exposes seam control procedures in its public API.
2. Seam controls are private hooks (`Install_Hook` / `Clear_Hook`) available
   only to child units.
3. Test package `OpenCL.RT.FS.Test_Seam` (under `tests/smoke/`) remains the
   only caller and is compiled only in `tests.gpr`.
4. Release build (`opencl_wrapper.gpr`) excludes test seam usage by
   construction and must not emit `Test_Seam` symbols in `obj/`.

## Rationale

- Preserves deterministic TOCTOU testing in test builds.
- Removes seam control from release-facing API and usage path.
- Provides an auditable split between verification hooks and production
  artifact content.

## Consequences

- Tests retain deterministic swap injection for G32.
- Release artifact content is cleaner and less prone to accidental misuse of
  test-only controls.
- G36 evidence is required to confirm exclusion (`grep/find` over `obj/`).

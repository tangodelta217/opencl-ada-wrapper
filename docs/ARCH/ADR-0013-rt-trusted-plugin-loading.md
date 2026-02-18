# ADR-0013: RT Trusted Plugin Loading

**ID:** OCLW-ADR-0013
**Status:** Accepted
**Date:** 2026-02-18
**Decision Makers:** <ARCHITECT_ROLE>, <SEC_ROLE>, <RT_ROLE>, <VV_ROLE>, <CM_ROLE>
**References:** ADR-0011, ADR-0012, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Context

G8/G9 established signature enforcement, plugin integration, and strict RT
policy. However, dynamic loading via ambient environment variables remains a
hardening gap for deployment. Defense-grade RT operation requires a trusted and
auditable provider loading path controlled by configuration management (CM),
not ad-hoc process environment state.

## Decision

1. RT strict mode ignores crypto env vars
- In RT strict mode, `OCLW_CRYPTO_PLUGIN` and `OCLW_CRYPTO_SYMBOL` are ignored.
- Environment-variable based provider selection is treated as DEV/integration
  convenience only.

2. Explicit provider configuration is mandatory in RT
- RT startup must configure the provider explicitly through
  `Configure_Plugin(...)`.
- The configured plugin path must come from CM-controlled release
  configuration/baseline.

3. Minimum plugin path/file checks before accept
- Plugin path must be absolute.
- Target must be a regular file.
- File must not be world-writable.
- Optional hardening policy may additionally enforce owner/group and stricter
  permission mask.

4. Fail-closed policy
- If explicit configuration is missing, plugin checks fail, `dlopen/dlsym`
  fails, or provider verification is unavailable when required, runtime must
  reject loading (fail-closed).
- No fallback to source/JIT in RT profile.

## Consequences

- Reduces path injection and accidental provider substitution risk in RT.
- Moves plugin resolution to a deterministic, auditable CM-controlled input.
- Strengthens IV&V evidence because provider origin and file properties are
  validated before use.

## Alternatives Considered

1. Keep env vars active in RT strict mode
- Rejected: high operational misconfiguration and injection risk.

2. Accept relative plugin paths in RT
- Rejected: ambiguous resolution and weak provenance control.

3. Check only `dlopen` success
- Rejected: insufficient hardening; file integrity/provenance controls are
  required before dynamic load.

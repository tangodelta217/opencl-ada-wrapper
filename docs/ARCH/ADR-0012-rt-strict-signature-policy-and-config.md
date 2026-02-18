# ADR-0012: RT Strict Signature Policy and Secure Provider Configuration

**ID:** OCLW-ADR-0012
**Status:** Accepted
**Date:** 2026-02-18
**Decision Makers:** <ARCHITECT_ROLE>, <SEC_ROLE>, <RT_ROLE>, <VV_ROLE>, <CM_ROLE>
**References:** ADR-0010, ADR-0011, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Context

Post-G8, the architecture has:
- fail-closed signature enforcement hooks;
- dynamic plugin integration point (`dlopen`/`dlsym`);
- test/reference verifiers to validate end-to-end flow.

For defense/EW RT operation, this is not sufficient without stricter policy
constraints for signature mandate, algorithm admissibility, and secure provider
configuration governance.

## Decision

1. RT mandatory signature policy
- In RT profile, `signature_required=1` is mandatory.
- Kernel packs that do not require signature are invalid for RT deployment.
- Runtime must fail-closed if this policy is not met.

2. TEST algorithms forbidden in RT
- In RT profile, `signature_alg` values with prefix `TEST-` are prohibited.
- This prohibition applies even if a verifier/plugin can technically validate
  that value.
- Runtime must fail-closed on `TEST-*` algorithm use in RT.

3. Provider configuration priority
- Preferred configuration model for RT is explicit provider registration via
  controlled API/config artifact managed by CM.
- Environment variables are accepted for DEV/integration, but are not the
  preferred control plane for RT operational deployment.
- RT deployment baseline must define immutable provider identity and location.

4. Gate evidence requirement
- Gate G9 acceptance evidence must include
  `smoke_rt_strict_policy` with `RESULT=PASS`.
- Minimum G9 strict-policy evidence includes:
  - reject path when `signature_required=0` in RT;
  - reject path when `signature_alg=TEST-*` in RT;
  - accept path with approved algorithm/provider wiring.

## Consequences

- RT profile moves from "signature capable" to "signature mandatory".
- Test-only algorithms are structurally separated from operational algorithms.
- Configuration attack surface through ambient environment is reduced in RT.
- CM and auditability requirements for provider binary/config are reinforced.

## Alternatives Considered

1. Keep `signature_required` optional in RT
- Rejected: allows unauthenticated artifacts in mission profile.

2. Permit `TEST-*` algorithms in RT behind waivers
- Rejected: weakens operational boundary and increases misuse risk.

3. Continue using env vars as primary RT provider configuration
- Rejected: weak governance and increased path-injection/supply-chain exposure.

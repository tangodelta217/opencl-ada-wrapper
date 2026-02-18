# ADR-0007: Program Binaries No-JIT RT Path

**ID:** OCLW-ADR-0007
**Status:** Accepted
**Date:** 2026-02-10
**Decision Makers:** <ARCHITECT_ROLE>, <VV_ROLE>, <RT_ROLE>
**References:** <INDRA_INTERNAL_POLICY_REF>

## Context

En perfiles defense-grade, la compilacion JIT de kernels en runtime introduce
riesgos de determinismo, dependencia de permisos de filesystem y variabilidad
de driver. G3 evidencio que los entornos sandboxed pueden requerir control
explicito de cache/temp para que `clBuildProgram` funcione.

Para RT/EW se requiere una ruta estable no-JIT con artefactos controlados.

## Decision

1. Soporte explicito de binarios en Core:
- Se soportara `Get_Binary` (extraccion) y `Create_From_Binary` (carga).
- Build from source queda como ruta dev/test y offline integration.

2. Portabilidad de binarios:
- Los binarios OpenCL **NO** se asumen portables entre vendors/drivers/devices.
- Cada binario debe estar asociado a fingerprint de plataforma/dispositivo/driver.

3. Politica de mismatch de fingerprint:
- En perfil RT, si fingerprint no coincide: **FAIL controlado** (sin fallback JIT).
- En perfil dev/tooling se podra evaluar fallback futuro (fuera del alcance de
  esta decision).

4. Diagnostico y evidencia:
- La ruta de binario mantendra `Status_Code` + diagnostico acotado.
- Gate G4 debera incluir evidencia de smoke de binary roundtrip en estado PASS.

## Alternatives Considered

1. Mantener solo build-from-source en runtime.
- Rechazada: no cumple objetivos RT/EW de no-JIT y control determinista.

2. Asumir binarios portables por version OpenCL.
- Rechazada: ignora dependencia real de vendor/driver/device.

3. Fallback automatico a JIT en RT ante mismatch.
- Rechazada: contradice politica no-JIT en mision.

## Consequences

- Se incorpora trabajo de implementacion para APIs de extraccion/carga de
  binarios y validacion de fingerprint.
- V&V debe ampliar evidencia para cubrir binary roundtrip y casos de mismatch.
- CM debe gestionar artefactos binarios por baseline de HW/SW aprobado.

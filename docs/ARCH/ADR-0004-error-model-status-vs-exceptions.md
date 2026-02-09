# ADR-0004: Error Model - Status Codes vs Exceptions

**ID:** OCLW-ADR-0004
**Status:** Accepted
**Date:** 2026-02-09
**Decision Makers:** <ARCHITECT_ROLE>
**References:** <INDRA_INTERNAL_POLICY_REF>

## Context

El wrapper Ada necesita un modelo de error apto para uso defense-grade:
- comportamiento determinista y trazable en runtime,
- interoperabilidad ABI limpia con OpenCL C (`cl_int`),
- capacidad de uso ergonomico en tooling sin contaminar paths RT/EW.

OpenCL reporta errores como enteros (`cl_int`) y no como excepciones.
Para capas superiores, usar enteros crudos degrada legibilidad y aumenta riesgo
de manejo inconsistente.

## Decision

1. API primaria sin excepciones:
- `OpenCL.Core` y `OpenCL.Errors` adoptan el modelo `Status_Code + out params`.
- El camino principal de control de errores es explicito y verificable.

2. API opcional con excepciones (futuro, no G0):
- Se permite una capa de conveniencia para tooling/entorno no RT.
- No se permite como API principal de RT/EW.
- Debe mapear de forma 1:1 desde `Status_Code` para no perder trazabilidad.

3. Representacion y conversion de `cl_int`:
- `OpenCL.Raw.API` mantiene `cl_int` como tipo ABI C.
- `OpenCL.Errors.Status_Code` representa el mismo dominio de valores de estado.
- Se definen conversiones explicitas Raw <-> Core:
  - `From_Raw (Code : cl_int) return Status_Code`
  - `To_Raw (Status : Status_Code) return cl_int`
- Codigos desconocidos se preservan sin colisionar con constantes conocidas.

## Alternatives Considered

1. Excepciones como API principal en Core.
- Rechazada: reduce predictibilidad y dificulta el control RT/EW.

2. Enteros crudos (`cl_int`) en todas las capas.
- Rechazada: menor legibilidad y mayor riesgo de manejo inconsistente.

3. Modelo dual con status primario + excepciones opcionales (seleccionada).
- Equilibra determinismo y ergonomia en tooling.

## Consequences

- Se simplifica IV&V en paths criticos: errores visibles en contratos de llamada.
- Se mantiene trazabilidad ABI con OpenCL sin acoplar Core a detalles C.
- Las pruebas y logs pueden validar estados explicitamente sin inspeccionar
  stack traces.

## Impact

- `docs/ARCH/SDD.md` debe reflejar:
  - seccion `OpenCL.Errors`,
  - politica de no excepciones como camino principal en `OpenCL.Core`.
- En futuras implementaciones, cualquier API con excepciones debe marcarse
  como convenience/no RT y documentar su mapeo a `Status_Code`.

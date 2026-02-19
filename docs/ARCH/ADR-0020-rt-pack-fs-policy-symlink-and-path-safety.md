# ADR-0020: RT Pack FS Policy (Symlink and Path Safety)

**ID:** OCLW-ADR-0020  
**Status:** Accepted  
**Date:** 2026-02-19  
**Decision Makers:** <ARCHITECT_ROLE>, <SEC_ROLE>, <RT_ROLE>, <VV_ROLE>, <CM_ROLE>  
**References:** `docs/ARCH/Threat_Model_RT_Packs.md`, ADR-0008, ADR-0012,
ADR-0013, ADR-0019, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Context

El threat model RT identifica:

- **TM-T3:** ataques de symlink/path traversal sobre `pack_dir`.
- **TM-G1:** gap de cobertura y endurecimiento pendiente en path safety.

En perfil defense-grade RT strict, `manifest.kpack` y `program.bin` son
artefactos de alta criticidad y no deben resolverse a ubicaciones fuera del
boundary operativo aprobado.

## Decision

1. Rechazo de symlink en RT strict
- En RT strict, el loader rechaza `manifest.kpack` y `program.bin` si son
  symbolic links.
- El rechazo aplica aunque el symlink apunte a una ruta existente o parezca
  confiable.
- Rationale: eliminar ambiguedad de resolucion y minimizar superficie de
  sustitucion/exfiltracion de artefactos.

2. Canonicalizacion y containment de `pack_dir`
- `pack_dir` se canonicaliza al inicio de la carga RT.
- Los paths efectivos de `manifest.kpack` y `program.bin` deben permanecer
  dentro del `pack_dir` canonical.
- Se rechaza cualquier escape por:
  - componentes `..`,
  - resoluciones que salgan del prefijo canonical esperado,
  - errores de canonicalizacion/verificacion.
- En RT strict no se permiten entradas de path arbitrarias para archivos del
  pack: solo nombres canonicos del contrato (`manifest.kpack`, `program.bin`)
  bajo `pack_dir`.

3. Codigo de error para violaciones de politica FS
- Se adopta codigo dedicado: `OCLW_FS_POLICY_VIOLATION`.
- Justificacion:
  - separa claramente errores de policy FS de errores semanticos de manifest
    (`OCLW_PACK_FORMAT_ERROR`),
  - mejora triage operativo e IV&V,
  - facilita telemetria de seguridad y respuesta a incidentes.
- Compatibilidad:
  - si algun caller legado mapea a `OCLW_PACK_FORMAT_ERROR`, el comportamiento
    sigue fail-closed.

4. Politica de rechazo
- Cualquier violacion FS (symlink/path escape/canonicalizacion invalida):
  fail-closed.
- No fallback a source/JIT en RT.

## Consequences

- Reduce riesgo de path traversal y sustitucion indirecta de artefactos.
- Mejora auditabilidad al distinguir formato de manifest vs policy FS.
- Requiere pruebas negativas especificas en el gate de seguridad de filesystem.

## Evidence (Gate G31)

Gate G31 debe incluir evidencia explicita:

- smoke: `smoke_rt_pack_symlink_escape`
- criterio: `RESULT=PASS`
- verificaciones minimas:
  - symlink en `manifest.kpack` rechazado
  - symlink en `program.bin` rechazado
  - intento de escape de path rechazado
  - status de rechazo en dominio FS (`OCLW_FS_POLICY_VIOLATION` o mapping
    fail-closed documentado)

## Alternatives Considered

1. Reusar solo `OCLW_PACK_FORMAT_ERROR` para todo rechazo FS
- Rechazada: menor precision diagnostica y peor trazabilidad de seguridad.

2. Permitir symlink si apunta dentro de `pack_dir`
- Rechazada: incrementa complejidad y posibilidad de bypass/TOCTOU.

3. Validar solo existencia de archivo sin containment canonical
- Rechazada: insuficiente frente a traversal y resolucion indirecta.

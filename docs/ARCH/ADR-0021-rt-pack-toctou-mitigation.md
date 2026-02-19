# ADR-0021: RT Pack TOCTOU Mitigation (Manifest/Binary Swap)

**ID:** OCLW-ADR-0021  
**Status:** Accepted  
**Date:** 2026-02-19  
**Decision Makers:** <ARCHITECT_ROLE>, <SEC_ROLE>, <RT_ROLE>, <VV_ROLE>, <CM_ROLE>  
**References:** `docs/ARCH/Threat_Model_RT_Packs.md`, ADR-0020,
`docs/ARCH/SDD.md`,
`docs/VV/Execution_Logs/GATES/G31/rerun_01/G31_Report.md`

## Context

El threat model identifica:

- **TM-T7:** ataque TOCTOU (verify-then-replace) sobre `manifest.kpack` y
  `program.bin`.
- **TM-G2:** gap de cobertura para deteccion determinista de swap durante la
  carga RT.

ADR-0020 cubre symlink/path traversal (TM-T3/TM-G1), pero no cierra por si
solo la ventana temporal entre validacion por path y uso del archivo.

## Decision

1. Lectura consistente por descriptor (RT strict)
- La carga de `manifest.kpack` y `program.bin` se hace con flujo por FD:
  - `open()` del archivo objetivo,
  - `fstat()` pre-lectura,
  - `read()` desde ese FD (sin reabrir por path),
  - `fstat()` post-lectura.
- Invariantes obligatorias entre pre y post:
  - tipo de archivo regular (`S_IFREG`),
  - `inode` estable,
  - `size` estable.
- Si cualquier invariante falla: rechazo fail-closed.

2. Semantica de error dedicada
- Se introduce `OCLW_FS_TOCTOU_DETECTED`.
- Semantica:
  - evidencia de condicion de carrera o sustitucion en ventana de carga,
  - dominio FS/security (no error semantico de manifest),
  - accion obligatoria: abortar carga RT (sin fallback a source/JIT).

3. Relacion con controles existentes
- Este ADR complementa ADR-0020:
  - ADR-0020: seguridad de resolucion de path (symlink/traversal),
  - ADR-0021: seguridad temporal de contenido/identidad durante lectura.
- Ambos controles son acumulativos en RT strict.

4. Nota de test seam (determinismo de pruebas)
- Para probar TOCTOU de forma repetible se permite un seam de test para
  sincronizar swap entre `fstat` pre y post.
- Requisito de arquitectura:
  - seam solo compilado/usable en builds de test,
  - seam no disponible en release/produccion,
  - sin degradar politica fail-closed.

## Consequences

- Mejora robustez frente a manifest swap y binary swap en ventana de carga.
- Incrementa ligeramente coste de I/O por `fstat` adicional.
- Mantiene trazabilidad clara de incidentes con estado interno dedicado.

## Evidence (Gate G32)

Gate G32 debe incluir evidencia explicita:

- smoke: `smoke_rt_toctou_manifest_swap`
- smoke: `smoke_rt_toctou_binary_swap`
- criterio minimo:
  - ambos casos detectados y abortados,
  - `RESULT=PASS` en ambos smokes,
  - status observado: `OCLW_FS_TOCTOU_DETECTED`.

## Alternatives Considered

1. Mantener solo validacion por path/canonicalizacion (ADR-0020)
- Rechazada: no cubre reemplazos temporales despues de resolver path.

2. Confiar solo en hash/firma final
- Rechazada: deteccion tardia y peor diagnostico de condicion TOCTOU FS.

3. Locks obligatorios de archivo entre procesos
- No adoptada como control principal:
  - complejidad operativa superior y menor portabilidad,
  - no sustituye verificacion de invariantes por FD.

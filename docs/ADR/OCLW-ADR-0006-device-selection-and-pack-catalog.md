# OCLW-ADR-0006: Seleccion determinista de device y pack catalog

**Estado:** Aprobado  
**Fecha:** 2026-02-19  
**Referencia:** ADR-0019, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Contexto
La ruta RT debe seleccionar de forma determinista un device objetivo y, sobre
un catalogo de subpacks, elegir el primer pack con fingerprint exacto sin
fallback permissivo.

## Decision
- Introducir `OpenCL.Core.Device_Selection.Select_Device` con orden
  determinista:
  - `device_vendor`, `device_name`, `driver_version`,
  - `platform_vendor`, `platform_name`,
  - desempate por indices de enumeracion.
- Introducir `OpenCL.RT.Catalog.Load_From_Catalog`:
  - recorre subdirectorios en orden determinista,
  - selecciona el primer subpack con match exacto de fingerprint,
  - devuelve `OCLW_FINGERPRINT_MISMATCH` si no hay match (fail-closed).
- `OpenCL.RT.Loader.Select_Device` delega en el selector determinista para
  eliminar ambiguedad por orden de enumeracion.

## Consecuencias
- Comportamiento reproducible entre ejecuciones y auditable en IV&V/CM.
- Soporte de "fat packs" sin recompilar en mision.
- Fail-closed mantenido en RT strict cuando no existe subpack valido.

## Evidencia
- Smoke `smoke_pack_catalog_selection`:
  - caso positivo: selecciona variante valida y ejecuta `add1`,
  - caso negativo: catalogo sin match -> `OCLW_FINGERPRINT_MISMATCH`,
  - `RESULT=PASS`.

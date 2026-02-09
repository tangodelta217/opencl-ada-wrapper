# OCLW-ADR-0002: Build Skeleton con gprbuild y link OpenCL configurable

**Estado:** Aprobado
**Fecha:** 2026-02-09
**Referencia:** <INDRA_INTERNAL_POLICY_REF>

## Contexto
Se necesita un esqueleto compilable para iniciar integracion continua temprana,
con soporte explicito para Ada 2012/2022 y sin dependencias externas nuevas.
Tambien se requiere enlace configurable de OpenCL para distintos entornos.

## Decision
- Usar `gprbuild` como sistema de build inicial.
- Definir `opencl_wrapper.gpr` como library project base del wrapper.
- Definir `tests/tests.gpr` para compilar el smoke test.
- Configurar link OpenCL por defecto con `-lOpenCL` en Linux.
- Permitir override mediante variable de entorno `OPENCL_LIB_NAME`.
- Permitir override por edicion directa de `Default_OpenCL_Library`
  o del atributo `Linker_Options` en los `.gpr`.

## Consecuencias
- El proyecto puede compilarse desde fases tempranas aun con API minima.
- El comportamiento de link queda explicito y trazable en configuracion.
- Integraciones en plataformas no estandar pueden ajustar el link sin
  introducir cambios funcionales en codigo Ada.

## Alternativas Consideradas
1. Usar `gnatmake` sin `.gpr`.
2. Fijar link OpenCL de forma hardcoded sin override.
3. Usar `gprbuild` con override configurable (seleccionada).

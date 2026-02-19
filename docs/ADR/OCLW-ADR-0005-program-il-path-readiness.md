# OCLW-ADR-0005: Program IL path readiness (`clCreateProgramWithIL`)

**Estado:** Aprobado  
**Fecha:** 2026-02-19  
**Referencia:** <INDRA_INTERNAL_POLICY_REF>

## Contexto
La baseline actual RT no-JIT usa carga de binarios (`Create_From_Binary`).
Se requiere preparar el binding para ruta IL (SPIR-V) cuando el runtime
OpenCL exponga `clCreateProgramWithIL`, sin introducir dependencias nuevas ni
acoplarse a hardware final.

## Decision
- Extender thin binding (`OpenCL.Raw.API`) con:
  - `clCreateProgramWithIL`.
  - constante `CL_INVALID_OPERATION` para diagnostico estable.
- Extender thick binding (`OpenCL.Core.Programs`) con:
  - `Create_From_IL (Ctx, Data, Prg, Status)`.
- Mantener politica de errores por `Status_Code` (sin excepciones como camino
  principal).
- Considerar `CL_INVALID_OPERATION` como salida controlada para runtimes sin
  soporte IL.
- Añadir smoke `smoke_program_il_path`:
  - usa IL dummy para comprobar que la ruta responde de forma controlada;
  - reporta `RESULT=SKIP` en no-soporte esperado;
  - no rompe harness ni CI en entornos OpenCL 1.2/PoCL.

## Consecuencias
- El wrapper queda preparado para evolucionar hacia cargas IL reales.
- Se mejora trazabilidad de compatibilidad runtime sin requerir target HW.
- No cambia la semantica RT strict vigente (no-JIT y fail-closed se mantienen).

## Evidencia requerida
- `gprbuild -P tests/tests.gpr` en verde.
- `tools/run_smoke.sh` en verde.
- Smoke `smoke_program_il_path` presente en `tests/tests.gpr` y harness.

# OCLW-ADR-0004: Whitelist de build options en RT strict

**Estado:** Aprobado
**Fecha:** 2026-02-19
**Referencia:** <INDRA_INTERNAL_POLICY_REF>

## Contexto
La ruta RT strict carga programas desde Kernel Pack y ejecuta politica
fail-closed. Permitir opciones de build arbitrarias en runtime incrementa
variabilidad, reduce determinismo y abre superficie de configuracion insegura
en despliegue defense-grade.

## Decision
- Introducir politica en `OpenCL.RT.Policy` con:
  - `Is_Build_Options_Allowed (Options : String) return Boolean`.
- Definir allowlist minima en RT strict:
  - `""`
  - `"-cl-std=CL1.2"`
- Definir denylist explicita de referencia:
  - tokens `-I*`
  - tokens `-D*`
  - `-cl-opt-disable`
- Integrar enforcement en `Create_Program_From_Pack_Strict_RT`:
  - si no permitido -> `OCLW_BUILD_OPTIONS_DISALLOWED` y rechazo fail-closed.
- Mantener modo DEV/no-strict sin enforcement de allowlist para no romper
  workflows de laboratorio.

## Consecuencias
- RT strict reduce variabilidad operacional y evita flags no aprobadas.
- La politica es auditable con un `Status_Code` interno especifico.
- DEV conserva flexibilidad en pruebas/integracion fuera de strict RT.

## Evidencia requerida
- Smoke `smoke_rt_build_options_policy`:
  - caso allow: PASS,
  - caso deny: rechazo esperado `OCLW_BUILD_OPTIONS_DISALLOWED`,
  - `RESULT=PASS` global.

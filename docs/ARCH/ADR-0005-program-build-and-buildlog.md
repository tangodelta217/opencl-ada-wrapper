# ADR-0005: Program Build and Build Log Exposure

**ID:** OCLW-ADR-0005
**Status:** Accepted
**Date:** 2026-02-09
**Decision Makers:** <ARCHITECT_ROLE>
**References:** <INDRA_INTERNAL_POLICY_REF>

## Context

Para escenarios industriales, el diagnostico de fallos de compilacion OpenCL es
critico en integracion, commissioning y soporte de campo. En OpenCL, el estado
de build por si solo (`cl_int`) no aporta suficiente detalle sin el build log.

Adicionalmente, los logs retornados por drivers pueden tener tamanos grandes o
anomalos. Se requiere una politica defensiva para evitar reservas no acotadas.

## Decision

1. Exposicion obligatoria de build log:
- El wrapper **DEBE** exponer API para recuperar build log de programa por
  dispositivo.
- El build log forma parte del contrato de diagnostico y de la evidencia V&V.

2. Clamping de logs:
- La recuperacion de logs aplicara limite `Max_Build_Log_Bytes`.
- Si el tamano reportado excede el limite, se truncara de forma controlada.
- No se permiten reservas no acotadas basadas solo en tamano reportado por driver.

3. Manejo de `CL_COMPILER_NOT_AVAILABLE`:
- En pruebas smoke de compilacion desde source, este estado se tratara como
  `SKIP` controlado (no crash).
- Debe registrarse explicitamente en evidencia de gate.

4. Politica de uso:
- Build from source queda definido como ruta de **dev/test**.
- Perfil RT/EW usara binaries precompilados/validados.

## Alternatives Considered

1. No exponer build log.
- Rechazada: insuficiente para analisis de fallos en integracion industrial.

2. Exponer build log sin limite de tamano.
- Rechazada: riesgo de consumo de memoria no acotado.

3. Tratar `CL_COMPILER_NOT_AVAILABLE` como error fatal en smoke.
- Rechazada: reduce portabilidad de pruebas y no refleja naturaleza del entorno.

## Rationale

- Compatibilidad: permite operar en entornos heterogeneos donde el compilador
  OpenCL puede no estar disponible.
- Diagnosticos: el build log es esencial para root-cause analysis.
- Evidencia: habilita artefactos trazables y auditables para gates de calidad.

## Consequences

- El diseno de `OpenCL.Core.Programs` debe incluir `Status_Code + Build_Log`.
- Las pruebas de build-from-source deben distinguir claramente PASS/FAIL/SKIP.
- La documentacion de V&V debe capturar logs truncados y razon de truncamiento.

## Addendum 2026-02-09 (G3 Fix)

- `Create_From_Source` usa `Interfaces.C.Strings.New_String` para el source,
  pasa `const char**` mediante array de un elemento y usa `lengths = NULL`.
- `Build` usa `clBuildProgram` con `num_devices = 0` y `device_list = NULL`
  para build de todos los devices del contexto del programa.
- En caso de fallo de build, el smoke reporta:
  `status + status_int`, `CL_PROGRAM_BUILD_STATUS`,
  `CL_PROGRAM_BUILD_OPTIONS`, `build_log_bytes_reported`,
  `BUILD_LOG` acotado y `PROGRAM_SOURCE_HEAD`.

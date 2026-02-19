# ADR-0016: Multi-device Program Binaries and RT Policy

**ID:** OCLW-ADR-0016
**Status:** Accepted
**Date:** 2026-02-19
**Decision Makers:** <ARCHITECT_ROLE>, <RT_ROLE>, <VV_ROLE>, <CM_ROLE>
**References:** ADR-0007, ADR-0008, ADR-0012, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Context

OpenCL 1.2 modela `cl_program` potencialmente asociado a N dispositivos.
En ese caso, `CL_PROGRAM_BINARY_SIZES` y `CL_PROGRAM_BINARIES` son arreglos
indexados por dispositivo. Hasta ahora, la ruta principal de G4..G13A1 se ha
validado mayormente en escenarios de un solo dispositivo visible.

Para mantener correccion de API y trazabilidad defense-grade, se requiere
definir comportamiento explicito para multi-device tanto en DEV (flexible) como
en RT (estricto y determinista).

## Decision

1. API explicita para binarios multi-device
- Se define que la capa `Core.Programs` debe exponer capacidades por indice de
  dispositivo:
  - consultar cantidad de dispositivos (`num_devices`) asociados al programa;
  - consultar `binary_size` por indice;
  - obtener binario por indice;
  - opcion para recuperar arreglos completos (sizes + binaries) si el caller
    aporta buffers ya dimensionados.
- Reglas de contrato:
  - indice fuera de rango -> `Status_Code` explicito (sin excepciones);
  - buffers insuficientes -> `Status_Code` explicito;
  - sin asignaciones ocultas en camino RT.

2. Politica RT (single-device por defecto)
- RT strict por defecto: ejecutar con un unico dispositivo validado.
- Si el entorno expone N>1 dispositivos, hay dos modos permitidos por politica
  de sistema:
  - modo recomendado por defecto: requerir exactamente 1 dispositivo elegible
    tras filtro/fingerprint;
  - modo alternativo controlado: seleccionar exactamente 1 dispositivo de forma
    determinista (regla documentada y reproducible) y validar fingerprint
    completo antes de cargar/ejecutar.
- En ambos casos RT:
  - no fallback a source/JIT;
  - fail-closed ante ambiguedad o mismatch.

3. Politica DEV
- DEV/integracion puede trabajar con N dispositivos y explotar arreglos
  completos de binarios para analisis/diagnostico.
- Las rutas de tooling pueden generar artefactos por dispositivo y registrar
  evidencia de indice/fingerprint para trazabilidad CM/V&V.

4. Evidencia de gate (G14)
- G14 debe pasar en escenario de 1 dispositivo.
- Si el sistema bajo prueba expone >=2 dispositivos elegibles, los smokes de
  G14 deben ejecutar cobertura multi-device (indice, sizes y bins por device).
- Si no hay >=2 dispositivos, la parte multi-device se marca `SKIP` controlado
  con razon explicita en salida/logs.

## Consequences

- Se elimina ambiguedad de uso de `CL_PROGRAM_BINARY_SIZES/BINARIES` en
  escenarios multi-device.
- RT mantiene comportamiento determinista y auditable al acotar a un dispositivo
  efectivo por ejecucion.
- DEV conserva flexibilidad para diagnostico y preparacion de artefactos.

## Alternatives Considered

1. Mantener API single-device solamente
- Rechazada: no cubre correctamente el modelo OpenCL cuando `num_devices > 1`.

2. Habilitar ejecucion RT multi-device simultanea por defecto
- Rechazada: incrementa complejidad temporal y de validacion en perfil RT/EW.

3. Elegir dispositivo por “primer encontrado” sin regla estable
- Rechazada: no determinista y debil para auditoria/CM.

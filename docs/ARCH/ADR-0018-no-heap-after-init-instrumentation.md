# ADR-0018: No Heap After Init Instrumentation

**ID:** OCLW-ADR-0018
**Status:** Accepted
**Date:** 2026-02-19
**Decision Makers:** <ARCHITECT_ROLE>, <RT_ROLE>, <SEC_ROLE>, <VV_ROLE>, <CM_ROLE>
**References:** ADR-0012, ADR-0013, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Context

El perfil RT/EW requiere comportamiento temporal acotado y predecible. Aunque
el path no-JIT y fail-closed ya reduce incertidumbre, las asignaciones de heap
durante steady-state siguen siendo una fuente de jitter y de riesgo de
fragmentacion.

Se necesita una politica verificable en runtime que permita:
- detectar y contar asignaciones dinamicas,
- congelar asignaciones tras la fase de init,
- forzar fail-closed en RT strict si aparece heap post-init.

## Decision

1. Requisito operativo
- En RT steady-state no se permiten asignaciones de heap.
- La ventana permitida de heap se limita a fase de init controlada.

2. Enfoque tecnico
- Introducir instrumentacion de asignaciones basada en:
  - storage pool fijo/acotado para rutas RT,
  - contador global de asignaciones (`alloc_count`),
  - operacion `Freeze_Allocations` para cerrar ventana de heap.
- Tras `Freeze_Allocations`, cualquier solicitud de heap se trata como violacion
  de politica.

3. Politica por perfil
- DEV/Integracion:
  - se permite heap para diagnostico/herramientas,
  - se reporta contador de asignaciones y eventos post-freeze para evidencia.
- RT strict:
  - `Freeze_Allocations` es obligatorio antes de entrar en steady-state,
  - asignacion post-freeze => fail-closed (estado de error explicito).

4. Semantica de error y fail-closed
- Violacion de politica no-heap post-init se reporta con `Status_Code`
  interno de wrapper.
- En RT strict no hay fallback a modos permissivos.

5. Evidencia de gate
- Gate G17 debe incluir `smoke_rt_no_heap_after_init` con `RESULT=PASS`.
- El smoke debe demostrar:
  - fase init permitida,
  - `Freeze_Allocations` aplicada,
  - rechazo controlado de alloc post-freeze en modo RT strict.

## Consequences

- Mejora predictibilidad temporal de steady-state RT.
- Reduce superficie de regresiones por heap oculto en paths de mision.
- Aumenta auditabilidad IV&V/CM con evidencia runtime explicita.

## Alternatives Considered

1. Solo revision estatica de codigo (sin runtime check)
- Rechazada: no detecta todas las rutas dinamicas ni regresiones de integracion.

2. Politica no-heap solo documental
- Rechazada: insuficiente para enforcement defense-grade.

3. Instrumentacion solo en test harness
- Rechazada: no cubre enforcement en runtime RT strict.

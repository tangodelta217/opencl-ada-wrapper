# ADR-0014: Performance Measurement and Budgets

**ID:** OCLW-ADR-0014
**Status:** Accepted
**Date:** 2026-02-18
**Decision Makers:** <ARCHITECT_ROLE>, <RT_ROLE>, <VV_ROLE>, <CM_ROLE>
**References:** ADR-0012, ADR-0013, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Context

Los gates G4..G10 cubrieron funcionalidad RT no-JIT, firma y hardening de
carga del proveedor. Para control defense-grade de latencia y determinismo,
se necesita una infraestructura de medicion reproducible que permita fijar y
validar presupuestos temporales (budgets) sin depender del hardware final.

## Decision

1. Que medir
- Latencia host end-to-end por iteracion (host->device->kernel->device->host).
- Latencia de kernel en dispositivo usando profiling por eventos OpenCL cuando
  este disponible (`START`/`END` del comando).
- Tiempos de transferencia y sobrecostes del pipeline inferidos desde los dos
  indicadores anteriores.

2. Warm-up y repeticion
- Todo benchmark debe ejecutar warm-up inicial para estabilizar caches/JIT del
  driver en entorno DEV.
- Tras warm-up, ejecutar N iteraciones de medida con parametros fijos y salida
  textual estable para V&V.

3. Estadisticos obligatorios
- Reportar como minimo `min`, `avg`, `p50`, `p95`, `p99`.
- `p50/p95/p99` se usan para evaluar cola de latencia, no solo promedio.

4. Compatibilidad con profiling no disponible
- Si profiling por eventos no esta disponible, el benchmark no debe abortar
  automaticamente: debe reportar `profiling=UNAVAILABLE` y mantener medicion
  host end-to-end.
- Fallos de profiling se reportan con `Status_Code` claro, sin excepciones como
  camino principal.

5. Advertencia de representatividad
- Los resultados obtenidos fuera del target operacional (homelab/CI/DEV) no son
  representativos de performance de mision.
- Los numeros de estos benches son evidencia de regresion relativa y salud del
  stack, no aceptacion final de budget de plataforma objetivo.

6. Relacion con EW/RT budgets
- Los budgets RT/EW deben definirse por funcion critica y validarse sobre
  configuracion de referencia controlada por CM.
- Esta infraestructura permite detectar regresiones tempranas y sustentar
  evidencia de gate previa a pruebas en hardware final.

## Consequences

- Se habilita trazabilidad cuantitativa de latencia por gate y por commit.
- Se reduce riesgo de regresiones silenciosas de rendimiento.
- El pipeline V&V puede comparar percentiles entre ejecuciones homogeneas.

## Alternatives Considered

1. Medir solo tiempo total de harness
- Rechazada: no separa latencia del kernel frente a overhead host/transfer.

2. Medir solo promedio
- Rechazada: oculta cola de latencia y no sirve para analisis RT.

3. Exigir profiling como requisito duro
- Rechazada para infraestructura base: en algunos drivers el soporte puede ser
  parcial; se prioriza evidencia host reproducible sin bloquear el gate.

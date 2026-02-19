# ADR-0015: RT Pack E2E Benchmark (G13a.1)

**ID:** OCLW-ADR-0015
**Status:** Accepted
**Date:** 2026-02-18
**Decision Makers:** <ARCHITECT_ROLE>, <RT_ROLE>, <VV_ROLE>, <CM_ROLE>
**References:** ADR-0008, ADR-0012, ADR-0013, ADR-0014, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Context

G13 introdujo infraestructura de performance base (`bench_add1`) para medicion
host/device con profiling por eventos cuando disponible. Para aproximar la ruta
operacional RT no-JIT, se requiere un benchmark especifico de extremo a
extremo sobre Kernel Pack (manifest + binary) que cubra inicializacion cold y
comportamiento steady-state.

## Decision

1. Alcance de G13a.1 (que medir)
- RT init cold (single-shot):
  - lectura de pack,
  - parse/canonical checks de manifest,
  - verificacion fingerprint/hash/firma segun politica RT,
  - `Create_From_Binary` + `Build`,
  - setup de kernel/args para primera ejecucion.
- RT steady-state (repetitivo):
  - write/enqueue/read por iteracion sobre programa ya cargado,
  - metricas host end-to-end por iteracion,
  - metricas device por evento (`START`/`END`) si profiling esta disponible.

2. Metodologia obligatoria
- Warm-up: `W` iteraciones (no incluidas en estadisticos finales).
- Medicion: `N` iteraciones deterministas.
- Estadisticos: `min`, `avg`, `p50`, `p95`, `p99`.
- Salida estable para V&V con lineas `INFO ...` y `RESULT=...`.
- CSV opcional con datos por iteracion para post-analisis.

3. Variables operativas esperadas
- `OCLW_PACK_DIR`: directorio del pack a medir.
- `OCLW_BENCH_WARMUP`: warm-up iterations (default de bench si no se define).
- `OCLW_BENCH_ITERS`: measurement iterations (default de bench si no se define).
- `OCLW_CRYPTO_PLUGIN`/`OCLW_CRYPTO_SYMBOL`: solo en flujo DEV/integracion;
  RT estricto puede ignorarlas segun politica vigente.

4. Advertencia de representatividad
- Resultados en PoCL/CPU u otros entornos no target son evidencia de regresion
  funcional/temporal relativa, no aceptacion final de budget operacional.
- La aceptacion de budgets de mision requiere ejecucion en HW/driver target
  (FPGA/GPU y baseline congelado de software/driver).

5. Relacion con EW/defensa
- G13a.1 mide explicitamente ruta RT no-JIT con fail-closed, alineada con
  requerimientos de arranque controlado y predictibilidad temporal.
- El tiempo de cold init contribuye al budget de inicio de mision.
- El steady-state (p95/p99) sustenta control de cola de latencia para carga RT.

6. Evidencia minima de gate
- Gate G13A1 debe incluir:
  - `RESULT=PASS` del benchmark RT Pack E2E.
  - Metricas impresas al menos para host `p50/p99`.
  - Metricas device `p50/p99` cuando profiling este disponible.
  - Referencia a logs de build/run y reporte consolidado de gate.

## Consequences

- Se cierra la brecha entre benchmark sintetico (`bench_add1`) y ruta RT real
  basada en packs.
- Se habilita trazabilidad de latencia de inicializacion cold y steady-state.
- Se facilita comparacion de regresiones por baseline CM en entorno controlado.

## Alternatives Considered

1. Reusar solo `bench_add1`
- Rechazada: no cubre explicitamente carga/verificacion de pack en path RT.

2. Medir solo steady-state
- Rechazada: oculta costo de arranque, critico para budget de inicio en EW/RT.

3. Exigir profiling como precondicion dura
- Rechazada: se mantiene politica de degradacion controlada con metrica host
  cuando profiling no esta disponible.

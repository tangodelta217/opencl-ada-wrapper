# ADR-0017: KPack Parser Fuzzing and Limits

**ID:** OCLW-ADR-0017
**Status:** Accepted
**Date:** 2026-02-19
**Decision Makers:** <ARCHITECT_ROLE>, <RT_ROLE>, <VV_ROLE>, <SEC_ROLE>, <CM_ROLE>
**References:** ADR-0009, ADR-0012, ADR-0016, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Context

El parser de `manifest.kpack` es parte critica del path RT no-JIT y del modelo
fail-closed. Cualquier fallo de robustez (crash, lectura fuera de limites,
estado ambiguo) impacta disponibilidad y seguridad operacional en un sistema
EW/defense-grade.

Los gates previos introdujeron parse estricto y casos negativos dirigidos, pero
se requiere cobertura adicional con entradas malformadas de alta variacion
mediante fuzzing controlado y reproducible.

## Decision

1. Objetivo de robustez obligatorio
- El parser debe cumplir:
  - no crash (sin abort ni excepciones no controladas),
  - fail-closed ante entrada invalida,
  - limites estrictos y verificables.

2. Limites fail-closed del parser
- Definir y aplicar limites acotados como politica:
  - `max_manifest_bytes`,
  - `max_lines`,
  - `max_keys` (incluyendo control de duplicadas),
  - `max_key_len`,
  - `max_value_len`.
- Si cualquier limite se excede: rechazo explicito con `Status_Code` interno de
  formato/limite, sin truncado silencioso.

3. Estrategia de fuzzing
- Corpus versionado en repo con casos malformados base:
  - lineas sin `=`, claves vacias, claves desconocidas, duplicadas,
  - bytes invalidos/controles, UTF-8 invalido, lineas sobredimensionadas,
  - numericos fuera de rango y combinaciones inconsistentes.
- Mutacion pseudoaleatoria determinista:
  - seed reproducible por ejecucion,
  - operadores de mutacion acotados (insert/delete/flip/swap de bytes y lineas),
  - misma seed => misma secuencia de casos.

4. Presupuesto de ejecucion
- Presupuesto minimo por corrida de smoke:
  - tiempo objetivo: 2 segundos,
  - volumen objetivo: 2000 casos.
- Si se alcanza limite de tiempo antes de iteraciones objetivo, reportar
  contadores reales y razon de corte de forma explicita.

5. Reproducibilidad de fallos
- Ante fallo inesperado (crash, hang, status no esperado), guardar el input
  exacto como artefacto reproducible junto con:
  - seed,
  - indice de iteracion,
  - metadatos minimos del entorno.
- El artefacto debe permitir rerun determinista del caso.

6. Evidencia de gate
- G15 debe incluir smoke dedicado (`smoke_fuzz_kpack_parser`) con:
  - `RESULT=PASS` si no hay crash y el parser rechaza/acepta segun politica,
  - contadores impresos (total, rechazados esperados, aceptados validos,
    errores inesperados, tiempo total, seed usada).

## Consequences

- Aumenta confianza en robustez del parser ante entradas hostiles o corruptas.
- Mejora capacidad de diagnostico y regresion por reproducibilidad de fallos.
- Refuerza trazabilidad V&V/CM con evidencia cuantitativa por corrida.

## Alternatives Considered

1. Solo tests dirigidos sin fuzzing
- Rechazada: cobertura insuficiente del espacio de entradas malformadas.

2. Fuzzing no determinista sin seed controlada
- Rechazada: dificulta reproducibilidad IV&V y analisis post-fallo.

3. Sin limites estrictos de parse
- Rechazada: incompatible con requisitos de comportamiento acotado en RT.

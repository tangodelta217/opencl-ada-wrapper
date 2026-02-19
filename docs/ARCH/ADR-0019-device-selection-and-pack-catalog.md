# ADR-0019: Device Selection and Pack Catalog (Fat Packs)

**ID:** OCLW-ADR-0019
**Status:** Accepted
**Date:** 2026-02-19
**Decision Makers:** <ARCHITECT_ROLE>, <RT_ROLE>, <SEC_ROLE>, <VV_ROLE>, <CM_ROLE>
**References:** ADR-0008, ADR-0010, ADR-0012, ADR-0013, ADR-0016, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Context

El wrapper ya soporta Kernel Pack por fingerprint y politica RT strict
fail-closed. Para despliegues defense-grade se necesita soportar multiples
fingerprints sin recompilar en mision:
- varios device/driver aprobados por release,
- seleccion determinista de dispositivo cuando hay mas de uno,
- seleccion determinista del subpack correcto dentro de un catalogo ("fat pack").

## Decision

1. Seleccion determinista de device
- El runtime construye candidatos con fingerprint completo:
  - `platform_vendor`, `platform_name`, `platform_version`,
  - `device_vendor`, `device_name`, `device_version`, `driver_version`.
- Orden determinista de candidatos:
  1. `device_vendor` (lexicografico ascendente)
  2. `device_name` (lexicografico ascendente)
  3. `driver_version` (lexicografico ascendente)
  4. `platform_vendor` (lexicografico ascendente)
  5. `platform_name` (lexicografico ascendente)
  6. desempate por `platform_index` y `device_index` de enumeracion.
- Reglas de preferencia:
  - Si existe politica de preferencia explicita de vendor/device en
    configuracion RT aprobada por CM, se aplica antes del orden
    lexicografico.
  - Si no existe, rige solo el orden determinista definido arriba.

2. Pack catalog ("fat pack")
- Se define un catalogo como directorio que contiene N subpacks.
- Cada subpack contiene al menos:
  - `manifest.kpack`
  - `program.bin`
  - firma del subpack (campos `signature_*` en el manifiesto canonical).
- Orden de evaluacion de subpacks:
  - si hay indice explicito de catalogo aprobado por CM, se usa ese orden;
  - en ausencia de indice, orden lexicografico por nombre de subdirectorio.
- Regla de match:
  - el loader elige el primer subpack cuyo fingerprint coincide exacto con el
    dispositivo seleccionado.
  - firma e integridad se verifican por subpack antes de aceptar la carga.

3. Politica RT
- En RT strict:
  - no fallback a source/JIT,
  - si no hay subpack con match exacto de fingerprint => fail-closed,
  - si firma/hash/manifest del subpack candidato falla => fail-closed.
- En DEV:
  - se permite diagnostico de catalogo y reportes de no-match sin relajar la
    politica RT strict de produccion.

4. Trazabilidad y evidencia
- Gate G24 debe incluir `smoke_pack_catalog_selection` con `RESULT=PASS`.
- El smoke debe evidenciar:
  - orden determinista aplicado,
  - subpack seleccionado,
  - caso de no-match controlado (fail-closed) cuando aplique.

## Consequences

- Un unico release puede incluir varios subpacks aprobados para COTS distintos
  sin recompilar en mision.
- Se mantiene determinismo operacional y auditabilidad de seleccion.
- Se evita comportamiento ambiguo por orden no estable del runtime.

## Alternatives Considered

1. Un pack por deployment (sin catalogo)
- Rechazada: aumenta complejidad logistico-CM y necesidad de rebuild/retarget.

2. Seleccion "primer device enumerado" sin orden estable
- Rechazada: comportamiento no determinista entre plataformas/drivers.

3. Catalogo con fallback permissivo si no hay match
- Rechazada: rompe politica RT strict fail-closed.

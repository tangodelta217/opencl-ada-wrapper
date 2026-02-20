# ADR-0024: EW MLP Demo Quantized Int-Only

**ID:** OCLW-ADR-0024  
**Status:** Accepted  
**Date:** 2026-02-20  
**Decision Makers:** <ARCH_ROLE>, <RT_ROLE>, <VV_ROLE>  
**References:** `docs/ARCH/SDD.md`, `docs/REQ/SRS.md`, `docs/REQ/Traceability.md`, `docs/DEMO/EW_MLP_Demo.md`

## Context

Se requiere una demo tecnica EW/RT que permita demostrar:
- Correctitud determinista de inferencia MLP en Ada/OpenCL.
- Ruta RT no-JIT usando Kernel Packs en lugar de build from source en runtime.
- Evidencia verificable de performance minima (`p50`/`p99`) sin depender de
  datos sensibles ni de un modelo operacional real.

La demo debe integrarse al repositorio sin introducir dependencias nuevas y con
trazabilidad REQ -> TEST -> EVIDENCE.

## Decision

1. Inferencia cuantizada **int-only**
- El demostrador MLP usa aritmetica entera para reducir variabilidad numerica y
  facilitar comparacion exacta CPU vs OpenCL.
- Topologia objetivo de demo: `Input=64`, `Hidden=96`, `Output=4`, ReLU.

2. Pesos deterministas embebidos
- Los pesos y sesgos de demo se embeben en codigo (sin archivos externos de
  pesos) para reducir superficie de configuracion y mejorar reproducibilidad.
- Se evita dependencia de pipelines de entrenamiento para esta fase de demo.

3. Dataset sintetico EW-like no sensible
- Se usa dataset sintetico determinista de 4 clases por banda.
- El dataset sirve como proxy tecnico para validacion del pipeline, no como
  representacion de entorno operacional real.

4. Ubicacion de la demo
- La demo vive en `tests/` (smokes/bench), no en el core del wrapper.
- El core RT solo recibe cambios minimos estrictamente necesarios para soportar
  ejecucion de la demo (si aplica en fases posteriores).

## Consequences

Beneficios:
- Reproducibilidad alta para V&V (comparacion bit-exact, dataset fijo, output
  estable).
- Menor complejidad de despliegue para demo y CI.
- Encaje natural con politica RT no-JIT y trazabilidad de gates.

Limitaciones:
- No representa un modelo entrenado operacional ni calidad de clasificacion de
  mision.
- No sustituye validacion en hardware final ni datasets reales aprobados.

Extensiones futuras:
- Carga de pesos externos versionados/firma de modelo.
- Ruta SPIR-V/IL cuando aplique.
- Escalado multi-device y perfiles de performance por target.

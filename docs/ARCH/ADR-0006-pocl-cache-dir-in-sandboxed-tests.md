# ADR-0006: PoCL Cache Directory in Sandboxed Tests

**ID:** OCLW-ADR-0006
**Status:** Accepted
**Date:** 2026-02-09
**Decision Makers:** <ARCHITECT_ROLE>, <DEVSECOPS_ROLE>, <VV_ROLE>
**References:** <INDRA_INTERNAL_POLICY_REF>

## Context

PoCL utiliza cache y ficheros temporales en disco durante compilacion JIT de
kernels (`clBuildProgram`). Por defecto, esos artefactos se escriben bajo
`$XDG_CACHE_HOME` o `$HOME/.cache`.

En ejecuciones sandboxed (por ejemplo con permisos tipo workspace-write), el
`HOME` efectivo o rutas por defecto del cache pueden no ser escribibles para el
proceso de test. Cuando esto sucede, la compilacion de kernels puede fallar con
errores de inicializacion de cache y diagnosticos poco accionables.

## Decision

El harness de smoke tests (`tools/run_smoke.sh`) fija `POCL_CACHE_DIR` a un
directorio escribible dentro del workspace cuando la variable no viene definida
externamente:

- `POCL_CACHE_DIR=$REPO_ROOT/.pocl_kcache`

Adicionalmente, cuando el harness fija `POCL_CACHE_DIR` y `POCL_KERNEL_CACHE`
no esta definido, se fuerza:

- `POCL_KERNEL_CACHE=0`

Esto minimiza crecimiento de artefactos de cache en ejecuciones repetidas de
smokes bajo CI/local sandbox.

## Rationale

- Aumenta reproducibilidad en entornos restringidos de escritura.
- Reduce falsos fallos de smoke por problemas de permisos fuera del repo.
- Mantiene control explicito de artefactos temporales dentro del workspace.

## Consequences

- El comportamiento afecta solo a PoCL; otros drivers OpenCL ignoraran estas
  variables de entorno.
- Usuarios/CI pueden sobreescribir `POCL_CACHE_DIR` y/o `POCL_KERNEL_CACHE`
  antes de invocar el harness, preservando flexibilidad.
- `.pocl_kcache/` queda fuera de control de versiones (ignorando artefactos).

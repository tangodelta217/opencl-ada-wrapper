# PoCL Diagnostic Run 01

Objetivo: recolectar evidencia cuando `clBuildProgram` falla con log generico.

## Comandos ejecutados

```bash
POCL_DEBUG=1 POCL_KERNEL_CACHE=0 ./tests/bin/smoke_kernel_add1 > docs/VV/Execution_Logs/GATES/G3/diag_pocl_01/run.log 2>&1
ls -ld ~/.cache ~/.cache/pocl ~/.cache/pocl/kcache 2>&1 || true > docs/VV/Execution_Logs/GATES/G3/diag_pocl_01/cache_perm.log
find ~/.cache/pocl -maxdepth 3 -not -user "$(whoami)" -ls 2>&1 | head -n 50 || true >> docs/VV/Execution_Logs/GATES/G3/diag_pocl_01/cache_perm.log
```

## Como repetir

Desde la raiz del repo:

```bash
POCL_DEBUG=1 POCL_KERNEL_CACHE=0 ./tests/bin/smoke_kernel_add1
ls -ld ~/.cache ~/.cache/pocl ~/.cache/pocl/kcache 2>&1 || true
find ~/.cache/pocl -maxdepth 3 -not -user "$(whoami)" -ls 2>&1 | head -n 50 || true
```

Artefactos:
- `run.log`
- `cache_perm.log`

# OpenCL Ada Wrapper

**Objetivo**
Repositorio para un wrapper en Ada de OpenCL y su infraestructura asociada.

**Quickstart: EW MLP Demo (RT no-JIT)**
- Compilar:
  - `gprbuild -P tests/tests.gpr`
- Ejecutar demo end-to-end:
  - `tools/run_demo_ew_mlp.sh`
- Ejecutar smoke + bench:
  - `OCLW_RUN_BENCH=1 tools/run_smoke.sh`
- Reporte showcase:
  - `docs/DEMO/EW_MLP_Showcase_Report.md`

**Release assets**
- Tag recomendado: `v0.2.1`
- Ver release y assets desde CLI:
  - `gh release view v0.2.1`

**Compilacion**
- Herramientas requeridas:
  - `gprbuild`
  - `gnatls` (toolchain GNAT Ada 2012/2022)
  - `gcc`
- Build de tests:
  - `gprbuild -P tests/tests.gpr`
- Build combinado (script):
  - `./tools/build.sh`
- Logs de build local:
  - `docs/VV/Execution_Logs/local/<UTC_TIMESTAMP>_build.log`

**Configuracion de Link OpenCL**
- Valor por defecto en Linux: `-lOpenCL`.
- Override por variable de entorno:
  - `export OPENCL_LINK_FLAG=-lOpenCL`
  - `gprbuild -P tests/tests.gpr`
- En entornos no estandar, `OPENCL_LINK_FLAG` puede incluir rutas:
  - `export OPENCL_LINK_FLAG=\"-L/ruta/opencl -lOpenCL\"`
  - `export OPENCL_LINK_FLAG=/usr/lib/x86_64-linux-gnu/libOpenCL.so`

**Smoke Test**
- Test minimo implementado: `OCLW-TST-0002` (enumeracion de plataformas/dispositivos OpenCL).
- Compilar y ejecutar:
  - `gprbuild -P tests/tests.gpr`
  - `./tests/bin/smoke_platforms`
  - o localizarlo: `find . -name smoke_platforms -type f -executable -print -quit`
- Flujo recomendado (build + run + evidencias):
  - `./tools/run_smoke.sh`
- Guardar evidencia en logs:
  - Build: `docs/VV/Execution_Logs/local/<UTC_TIMESTAMP>_build.log`
  - Run: `docs/VV/Execution_Logs/local/<UTC_TIMESTAMP>_smoke_run.log`

**Documentacion**
- `docs/ARCH/SDD.md` Arquitectura por capas y diseno de alto nivel.
- `docs/ARCH/ADR-0001-baseline-opencl-1.2.md` Decision de baseline OpenCL 1.2 con capabilities.
- `docs/ADR/OCLW-ADR-0002-build-skeleton-gprbuild.md` Decision de build skeleton y politica de link OpenCL.
- `docs/ADR/OCLW-ADR-0003-thin-ffi-platform-device-enumeration.md` Decision de FFI minimo para enumeracion.
- `docs/REQ/SRS.md` Requisitos del sistema.
- `docs/VV/SVVP.md` Plan de verificacion y validacion.
- `docs/CM/SCMP.md` Plan de gestion de configuracion.
- `docs/PM/Risk_Register.md` Registro de riesgos.

# OpenCL Ada Wrapper

**Objetivo**
Repositorio para un wrapper en Ada de OpenCL y su infraestructura asociada.

**Compilacion**
- Requisito: `gprbuild` con toolchain GNAT (Ada 2012/2022).
- Build de wrapper:
  - `gprbuild -P opencl_wrapper.gpr -p`
  - salida esperada: `lib/libopencl_wrapper.a`
- Build de tests:
  - `gprbuild -P tests/tests.gpr -p`
- Build combinado (script):
  - `./tools/build.sh`

**Configuracion de Link OpenCL**
- Valor por defecto en Linux: `-lOpenCL`.
- Override por variable de entorno:
  - `OPENCL_LIB_NAME=OpenCL gprbuild -P tests/tests.gpr -p`
- Override en atributo del `.gpr`:
  - editar `Default_OpenCL_Library` o `package Linker / Linker_Options` en `opencl_wrapper.gpr` y `tests/tests.gpr`.

**Smoke Test**
- Test minimo implementado: `OCLW-TST-0002` (enumeracion de plataformas/dispositivos OpenCL).
- Compilar y ejecutar:
  - `gprbuild -P tests/tests.gpr -p`
  - `./bin/tests/smoke_platforms`

**Documentacion**
- `docs/ARCH/SDD.md` Arquitectura por capas y diseno de alto nivel.
- `docs/ARCH/ADR-0001-baseline-opencl-1.2.md` Decision de baseline OpenCL 1.2 con capabilities.
- `docs/ADR/OCLW-ADR-0002-build-skeleton-gprbuild.md` Decision de build skeleton y politica de link OpenCL.
- `docs/ADR/OCLW-ADR-0003-thin-ffi-platform-device-enumeration.md` Decision de FFI minimo para enumeracion.
- `docs/REQ/SRS.md` Requisitos del sistema.
- `docs/VV/SVVP.md` Plan de verificacion y validacion.
- `docs/CM/SCMP.md` Plan de gestion de configuracion.
- `docs/PM/Risk_Register.md` Registro de riesgos.

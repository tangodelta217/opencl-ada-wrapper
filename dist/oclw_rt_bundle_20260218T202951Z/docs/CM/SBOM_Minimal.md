# SBOM Minimal (Build/Runtime)

**Proyecto:** OpenCL Ada Wrapper
**Tipo:** inventario minimo de dependencias conocidas

## 1. Alcance

Este SBOM minimo cubre dependencias observables en el repositorio para:

- build-time
- runtime

No sustituye un SBOM formal de sistema integrado.

## 2. Dependencias build-time conocidas

| Componente | Uso | Observacion |
| --- | --- | --- |
| GNAT (Ada toolchain) | Compilacion Ada | requerido para `gprbuild` de libreria y tests |
| GPRBuild | Orquestacion de build | usado con `opencl_wrapper.gpr` y `tests/tests.gpr` |
| GCC / linker del sistema | Link y objetos C/Ada | toolchain del host; requerido para build general |
| Bash | Scripts de build/test | `tools/build.sh`, `tools/run_smoke.sh` |
| Coreutils (chmod, etc.) | Soporte scripts/smokes | usado por smoke de plugin inseguro |
| GCC (C) para plugin de referencia | Solo DEV/test | build de `tools/crypto_provider_ref/*.c` |

## 3. Dependencias runtime conocidas

| Componente | Uso | Observacion |
| --- | --- | --- |
| libOpenCL (ICD loader) | API OpenCL host | requerido para ejecucion real de kernels |
| Driver/ICD vendor OpenCL | Backend de dispositivo | dependencia COTS del entorno |
| libc/libdl (`dlopen`/`dlsym`) | Carga dinamica plugin cripto | usado por `OpenCL.RT.Security` |
| Plugin cripto externo (`.so`) | Verificacion de firma | en RT debe ser provider aprobado y confiable |
| Ada runtime (libgnat) | Runtime de ejecutables Ada | requerido por binarios wrapper/tests |

## 4. Artefactos y contratos relevantes

- Proyecto libreria: `opencl_wrapper.gpr`
- Proyecto tests/harness: `tests/tests.gpr`, `tools/run_smoke.sh`
- Contrato plugin C ABI:

```c
int oclw_kpack_verify_v1(
  const char* signature_alg,
  const char* signer_id,
  const char* signature_value,
  const uint8_t* signing_text, size_t signing_text_len,
  const uint8_t* program_bin, size_t program_bin_len);
```

## 5. Nota PoCL

PoCL se usa como entorno de desarrollo/CI y evidencia V&V local.
No debe asumirse como dependencia obligatoria del despliegue operacional RT.

## 6. Exclusiones explicitas

- Plugin de referencia `tools/crypto_provider_ref` es **NOT CRYPTO** y no
  forma parte del runtime operacional defense-grade.

# RT Catalog Playbook (Pack Catalog Plug-and-Play)

**Proyecto:** OpenCL Ada Wrapper (INDRA/EW)  
**Perfil:** RT defense-grade (no-JIT, fail-closed)  
**Objetivo:** desplegar un catalogo de subpacks aprobados y seleccionar el
subpack correcto en runtime sin recompilar en mision.

## 1. Referencias de baseline

- G24 (catalog selection): `docs/VV/Execution_Logs/GATES/G24/rerun_01/G24_Report.md`
- G12 (homelab RT acceptance): `docs/VV/Execution_Logs/GATES/G12/rerun_01/Acceptance_Report.md`
- G30 (baseline audit): `docs/VV/Execution_Logs/GATES/G30/rerun_02/G30_Audit_Report.md`
- ADR catalogo: `docs/ARCH/ADR-0019-device-selection-and-pack-catalog.md`
- ADR plugin C ABI: `docs/ARCH/ADR-0011-crypto-provider-plugin-interface.md`
- ADR plugin allowlist/permisos RT:
  `docs/ARCH/ADR-0022-rt-crypto-plugin-allowlist-and-permissions.md`
- Contrato/Criterios de conformance del plugin: `docs/ARCH/Crypto_Provider_Conformance.md`
- Plugin ref (DEV/TEST): `tools/crypto_provider_ref/README.md`

## 2. Estructura recomendada del catalogo

```text
/opt/oclw/catalogs/<catalog_id>/
  001_<platform>_<device>_<driver>/
    manifest.kpack
    program.bin
  002_<platform>_<device>_<driver>/
    manifest.kpack
    program.bin
  003_...
```

Reglas operativas:

- Un subdirectorio por fingerprint aprobado.
- Prefijo numerico (`001_`, `002_`, ...) para orden estable.
- Cada subpack contiene solo `manifest.kpack` y `program.bin`.
- No mezclar artefactos temporales dentro del catalogo productivo.

## 3. Generacion offline de cada subpack (lista aprobada)

Prerequisitos:

```bash
cd /home/tangodelta/opencl-ada-wrapper
gprbuild -P tests/tests.gpr -p
```

Para cada entorno/fingerprint aprobado (ejecutar en el host/device objetivo de ese fingerprint):

```bash
catalog_root="/tmp/oclw_catalog_build_$(date -u +%Y%m%dT%H%M%SZ)"
subpack_dir="${catalog_root}/001_intel_haswell_5_0"
mkdir -p "${subpack_dir}"

export OCLW_PACK_DIR="${subpack_dir}"
./tests/bin/gen_pack_add1
```

Validacion minima por subpack:

```bash
test -f "${subpack_dir}/manifest.kpack"
test -f "${subpack_dir}/program.bin"
head -n 60 "${subpack_dir}/manifest.kpack"
```

Nota:

- `gen_pack_add1` genera binario valido para el fingerprint del entorno que lo ejecuta.
- Repetir el proceso para cada fingerprint de la lista aprobada.

## 4. Firma de subpacks (plugin ref vs plugin real)

### 4.1 DEV/TEST (plugin de referencia, NOT CRYPTO)

Construir plugin ref:

```bash
tools/crypto_provider_ref/build.sh
PLUGIN_REF="$(realpath tools/crypto_provider_ref/liboclw_crypto_provider_ref.so)"
```

Conformance del backend (recomendado):

```bash
OCLW_CRYPTO_PLUGIN="${PLUGIN_REF}" \
OCLW_CRYPTO_SYMBOL="oclw_kpack_verify_v1" \
./tests/bin/smoke_crypto_provider_conformance
```

Validacion funcional de enforcement (NOT CRYPTO):

```bash
OCLW_PACK_DIR="${subpack_dir}" \
OCLW_CRYPTO_PLUGIN="${PLUGIN_REF}" \
OCLW_CRYPTO_SYMBOL="oclw_kpack_verify_v1" \
./tests/bin/smoke_rt_signature_plugin
```

### 4.2 Produccion (plugin real aprobado)

Contrato C ABI requerido (v1):

```c
int oclw_kpack_verify_v1(
  const char* signature_alg,
  const char* signer_id,
  const char* signature_value,
  const uint8_t* signing_text, size_t signing_text_len,
  const uint8_t* program_bin, size_t program_bin_len);
```

Reglas operativas:

- `signature_required=1` en RT strict.
- No usar `signature_alg` con prefijo `TEST-` en RT.
- El plugin de produccion debe estar aprobado por la politica cripto del sistema.
- `tools/crypto_provider_ref/*` es solo DEV/TEST (NOT CRYPTO).

## 5. Despliegue en target

Ubicacion sugerida:

- Catalogo: `/opt/oclw/catalogs/<catalog_id>/`
- Plugin cripto: `/opt/oclw/crypto/libprovider.so`

Permisos y hardening:

```bash
chmod -R a-w /opt/oclw/catalogs/<catalog_id>
find /opt/oclw/catalogs/<catalog_id> -type d -exec chmod 755 {} \;
find /opt/oclw/catalogs/<catalog_id> -type f -exec chmod 644 {} \;

chmod 755 /opt/oclw/crypto/libprovider.so
```

Requisitos de operacion RT:

- Catalogo en filesystem de solo lectura (o bind-mount RO).
- Ruta de plugin absoluta y controlada por CM.
- Plugin dentro de directorio permitido por allowlist RT canonical
  (`OCLW_RT_PLUGIN_ALLOWLIST="dir1:dir2:..."`).
- Plugin regular file y no world-writable.
- Symlinks de plugin no permitidos en RT strict.
- Si la allowlist falta/esta vacia en RT strict: fail-closed.
- Fail-closed ante mismatch de hash/fingerprint/firma o plugin no confiable.

Configuracion minima recomendada en startup RT:

```bash
export OCLW_RT_PLUGIN_ALLOWLIST="/opt/oclw/crypto:/usr/local/lib/oclw"
# En RT strict, configurar plugin via API/config controlada por CM.
# OCLW_CRYPTO_PLUGIN/OCLW_CRYPTO_SYMBOL quedan para DEV/integracion.
```

Nota operativa (copy/paste) para validar plugin antes de arrancar:

```bash
PLUGIN_PATH="/opt/oclw/crypto/libprovider.so"
export OCLW_RT_PLUGIN_ALLOWLIST="/opt/oclw/crypto:/usr/local/lib/oclw"

# Requisitos minimos RT strict:
# 1) plugin en allowlist canonical,
# 2) regular file,
# 3) no symlink,
# 4) no world-writable.
test -f "${PLUGIN_PATH}"
test ! -L "${PLUGIN_PATH}"
perm_octal="$(stat -c '%a' "${PLUGIN_PATH}")"
[ $((10#${perm_octal} & 2)) -eq 0 ]
```

## 6. Checklist de verificacion (G24 + G12 + G30)

### 6.1 Catalog selection (G24)

```bash
./tests/bin/smoke_pack_catalog_selection
```

Esperado:

- `RESULT=PASS`
- caso positivo y caso no-match controlado.

### 6.2 RT acceptance subset (alineado a G12)

```bash
./tests/bin/smoke_rt_load_pack_add1
./tests/bin/smoke_rt_signature_plugin
./tests/bin/smoke_rt_strict_policy
./tests/bin/smoke_rt_untrusted_plugin
```

Esperado:

- `RESULT=PASS` en todos los tests anteriores.

### 6.3 Baseline audit (referencia G30)

Revisar reporte baseline:

```bash
cat docs/VV/Execution_Logs/GATES/G30/rerun_02/G30_Audit_Report.md
```

Esperado:

- `RESULT=PASS` y sin gates criticos faltantes.

## 7. Evidencias/logs a conservar

Guardar por release/catalogo:

1. Contexto:
   - UTC timestamp
   - `git rev-parse HEAD`
   - `uname -a`
2. Por subpack:
   - `manifest.kpack` final
   - `program.bin`
   - hash de ambos (`sha256sum`)
   - salida de `gen_pack_add1`
3. Firma/plugin:
   - ruta absoluta del plugin usado
   - allowlist RT efectiva usada en startup
   - permisos/owner del plugin (`ls -l`, `stat`)
   - resultado de `smoke_crypto_provider_conformance`
4. Verificacion RT:
   - salida de `smoke_pack_catalog_selection`
   - salida de smokes G12 subset
5. Auditoria:
   - referencia a `docs/VV/Execution_Logs/GATES/G24/rerun_01/G24_Report.md`
   - referencia a `docs/VV/Execution_Logs/GATES/G12/rerun_01/Acceptance_Report.md`
   - referencia a `docs/VV/Execution_Logs/GATES/G30/rerun_02/G30_Audit_Report.md`

## 8. Comandos minimos (copy/paste)

```bash
cd /home/tangodelta/opencl-ada-wrapper
gprbuild -P tests/tests.gpr -p

catalog_root="/tmp/oclw_catalog_build_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "${catalog_root}/001_target_a" "${catalog_root}/002_target_b"

OCLW_PACK_DIR="${catalog_root}/001_target_a" ./tests/bin/gen_pack_add1
OCLW_PACK_DIR="${catalog_root}/002_target_b" ./tests/bin/gen_pack_add1

tools/crypto_provider_ref/build.sh
PLUGIN_REF="$(realpath tools/crypto_provider_ref/liboclw_crypto_provider_ref.so)"
OCLW_CRYPTO_PLUGIN="${PLUGIN_REF}" OCLW_CRYPTO_SYMBOL="oclw_kpack_verify_v1" \
  ./tests/bin/smoke_crypto_provider_conformance

./tests/bin/smoke_pack_catalog_selection
tools/run_smoke.sh
cat docs/VV/Execution_Logs/GATES/G30/rerun_02/G30_Audit_Report.md
```

Resultado operacional esperado:

- Catalogo listo para despliegue RO.
- Validacion funcional PASS en seleccion de subpack y enforcement RT.
- Evidencia trazable a G24/G12/G30.

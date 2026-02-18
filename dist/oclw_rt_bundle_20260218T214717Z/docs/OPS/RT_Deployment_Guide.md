# RT Deployment Guide

**Proyecto:** OpenCL Ada Wrapper
**Perfil objetivo:** RT/EW defense-grade

## 1. Objetivo
Definir el handover operativo para despliegue RT no-JIT con Kernel Pack:

- artefacto de runtime: `manifest.kpack` + `program.bin`
- verificacion de fingerprint, hash y firma
- politica fail-closed ante cualquier mismatch

## 2. Referencias

- `docs/ARCH/SDD.md`
- `docs/ARCH/ADR-0010-kpack-signature-verification-rt-policy.md`
- `docs/ARCH/ADR-0012-rt-strict-signature-policy-and-config.md`
- `docs/ARCH/ADR-0013-rt-trusted-plugin-loading.md`

## 3. Flujo OFFLINE (build/release pipeline)

### 3.1 Generar pack base

1. Compilar binarios de test/herramientas:
   - `gprbuild -P tests/tests.gpr`
2. Generar pack base (ejemplo de referencia):
   - `tests/bin/gen_pack_add1`
3. Salida esperada:
   - `manifest.kpack`
   - `program.bin`

### 3.2 Calculo de signing input

Para firma/verificacion del pack, el signing input se basa en:

1. Manifest canonical **sin campos `signature_*`**.
   - usar `OpenCL.RT.Packs.Canonical_Signing_Text`
2. Bytes reales de `program.bin` para `Used`.

Forma conceptual:

```text
signing_input = bytes(canonical_manifest_without_signature_fields) || bytes(program.bin[0..Used-1])
```

Notas:

- `canonical_manifest_without_signature_fields` debe ser determinista.
- El verificador criptografico puede aplicar reglas internas adicionales, pero
  debe cubrir ambos componentes (manifest canonical + binario).

### 3.3 Rellenar campos de firma en manifest

Campos minimos para path con firma:

- `signature_required=1` (obligatorio en RT strict policy)
- `signature_alg=<algoritmo aprobado>`
- `signature_value=<firma serializada segun politica>`
- `signer_id=<identificador firmante>`

Reglas operativas:

- No usar `TEST-*` en RT.
- `signature_value` y `signature_alg` deben ser consistentes con el proveedor
  cripto del sistema.

## 4. Flujo RT (runtime de mision)

### 4.1 Configurar crypto provider

Configurar explicitamente el plugin con `Configure_Plugin`:

- path absoluto
- archivo regular
- no world-writable
- ruta bajo control CM (whitelist/read-only)

Ejemplo conceptual (Ada):

```ada
OpenCL.RT.Security.Configure_Plugin
  (Path   => "/opt/oclw/crypto/libprovider.so",
   Symbol => "oclw_kpack_verify_v1",
   Status => Status);
```

### 4.2 Activar strict RT policy

En RT usar path estricto:

- `Create_Program_From_Pack_Strict_RT`
- sin fallback a source/JIT
- `signature_required=1`
- rechazo de `signature_alg` prefijo `TEST-`

### 4.3 Cargar pack y ejecutar

Secuencia recomendada:

1. `Read_Manifest`
2. `Read_Binary`
3. `Verify_Binary` (size/hash)
4. `Select_Device` (fingerprint exacto)
5. `Create_Program_From_Pack_Strict_RT`
6. Crear kernel y ejecutar

## 5. Hardening checklist

- Pack (`manifest.kpack`, `program.bin`) en filesystem read-only.
- Plugin cripto en ruta whitelisted y bajo control CM.
- Plugin no world-writable.
- Configuracion del provider por API (`Configure_Plugin`) y no por env vars en RT.
- Mantener modo strict RT y fail-closed.

## 6. Diagnostico (Status_Code clave)

Estados comunes de rechazo:

- `OCLW_HASH_MISMATCH`
  - `program.bin` no coincide con hash declarado.
- `OCLW_FINGERPRINT_MISMATCH`
  - mismatch de plataforma/dispositivo/driver respecto al manifest.
- `OCLW_SIGNATURE_INVALID`
  - firma invalida, algoritmo no soportado por provider o verificacion fallida.
- `OCLW_PLUGIN_UNTRUSTED`
  - plugin no cumple checks de confianza (path/file/permisos).

Recomendacion de operacion:

- registrar `Errors.Image(Status)` + `status_int`
- no degradar a source path en RT

## 7. Evidencia operativa minima

- build: `gprbuild -P tests/tests.gpr` exit 0
- harness: `tools/run_smoke.sh` exit 0
- evidencia de smoke hardening:
  - `smoke_rt_untrusted_plugin` => `RESULT=PASS`

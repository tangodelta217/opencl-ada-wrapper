# Delivery Content (RT Release)

**Proyecto:** OpenCL Ada Wrapper
**Scope:** handover de release RT defense-grade

## 1. Objetivo

Definir el contenido minimo de entrega para un release RT y dejar claro que
artefactos son operacionales vs artefactos solo DEV/test.

## 2. Contenido obligatorio del release

### 2.1 Libreria wrapper

- Proyecto: `opencl_wrapper.gpr`
- Build recomendado:
  - `gprbuild -P opencl_wrapper.gpr -p`
- Entrega:
  - artefactos de libreria compilada segun pipeline CM
  - metadata de version/commit baseline

### 2.2 Contrato del plugin C ABI (provider externo)

Interfaz de integracion definida:

```c
int oclw_kpack_verify_v1(
  const char* signature_alg,
  const char* signer_id,
  const char* signature_value,
  const uint8_t* signing_text, size_t signing_text_len,
  const uint8_t* program_bin, size_t program_bin_len);
```

Regla de retorno:

- `0`: verificacion OK
- `!= 0`: verificacion FAIL

### 2.3 Formato de manifest y reglas canonical

Entregar especificacion de `manifest.kpack`:

- `key=value` UTF-8
- claves obligatorias del pack y firma
- canonical rules (orden fijo, parse estricto, sin `signature_*` para signing text)

Referencias:

- `docs/ARCH/SDD.md`
- `docs/ARCH/ADR-0009-kpack-canonical-manifest-and-tamper-tests.md`
- `docs/ARCH/ADR-0010-kpack-signature-verification-rt-policy.md`
- `docs/ARCH/ADR-0013-rt-trusted-plugin-loading.md`

### 2.4 Ejemplos de referencia (smokes)

No son artefacto de runtime, pero se entregan como referencia de validacion:

- `tests/smoke/gen_pack_add1.adb`
- `tests/smoke/smoke_rt_load_pack_add1.adb`
- `tests/smoke/smoke_rt_negative_cases.adb`
- `tests/smoke/smoke_rt_signature_enforcement.adb`
- `tests/smoke/smoke_rt_signature_plugin.adb`
- `tests/smoke/smoke_rt_strict_policy.adb`
- `tests/smoke/smoke_rt_untrusted_plugin.adb`

### 2.5 Evidencias V&V por gate (G4..G10)

- G4: `docs/VV/Execution_Logs/GATES/G4/verify_03/G4_Verification_Report.md`
- G5: `docs/VV/Execution_Logs/GATES/G5/rerun_01/G5_Report.md`
- G6: `docs/VV/Execution_Logs/GATES/G6/rerun_01/G6_Report.md`
- G7: `docs/VV/Execution_Logs/GATES/G7/rerun_01/G7_Report.md`
- G8: `docs/VV/Execution_Logs/GATES/G8/rerun_02/G8_Report.md`
- G9: `docs/VV/Execution_Logs/GATES/G9/rerun_02/G9_Report.md`
- G10: `docs/VV/Execution_Logs/GATES/G10/rerun_02/G10_Report.md`

Adicionalmente:

- cierres de gate en `docs/VV/Execution_Logs/GATES/Gx/Closure.md`

## 3. No parte del delivery operacional

**NO incluir como componente de seguridad operacional:**

- `tools/crypto_provider_ref/liboclw_crypto_provider_ref.so`
- cualquier verifier `TEST-*`

Motivo:

- plugin/verifier de referencia es **NOT CRYPTO** y solo aplica a DEV/test/CI.

## 4. Checklist de salida CM

- release tag/commit congelado
- artefactos y hashes registrados
- trazabilidad y riesgos actualizados
- evidencia V&V anexada al baseline

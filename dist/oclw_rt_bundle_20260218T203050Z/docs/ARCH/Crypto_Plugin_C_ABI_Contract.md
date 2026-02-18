# Crypto Provider Reference Plugin

**Scope:** DEV/TEST only (NOT CRYPTO)

Este directorio contiene un plugin de referencia para pruebas de integracion.
No es un proveedor criptografico aprobado para produccion RT.

## C ABI Contract (v1)

```c
int oclw_kpack_verify_v1(
  const char* signature_alg,
  const char* signer_id,
  const char* signature_value,
  const uint8_t* signing_text, size_t signing_text_len,
  const uint8_t* program_bin, size_t program_bin_len);
```

Semantica de retorno:

- `0` => verificacion OK
- `!= 0` => verificacion FAIL

## Nota operacional

- `liboclw_crypto_provider_ref.so` es **NOT CRYPTO** y se usa solo para
  validacion funcional en DEV/test/CI.
- No debe incluirse como componente de seguridad operacional en releases RT.

# ADR-0011: Crypto Provider Plugin Interface (C ABI)

**ID:** OCLW-ADR-0011
**Status:** Accepted
**Date:** 2026-02-18
**Decision Makers:** <ARCHITECT_ROLE>, <SEC_ROLE>, <RT_ROLE>, <VV_ROLE>, <CM_ROLE>
**References:** ADR-0010, `docs/ARCH/SDD.md`, <INDRA_INTERNAL_POLICY_REF>

## Context

G7 introdujo enforcement de firma en RT y un verificador inyectable de test.
Ese mecanismo cubre flujo funcional, pero no cumple por si solo la necesidad de
autenticidad defense-grade con proveedor criptografico aprobado.

Se requiere definir una interfaz estable para integrar verificacion externa sin
acoplar el core RT a una libreria criptografica concreta en este gate.

## Decision

1. Integracion por plugin C ABI (v1)
- La integracion con proveedor cripto se define mediante funcion C con ABI
  estable, cargable dinamicamente.
- Mecanismo de carga: `dlopen` + `dlsym`.
- La carga del plugin es opcional desde el punto de vista tecnico, pero en RT
  con `signature_required=1` la ausencia de verificador implica rechazo.

2. Variables de entorno de integracion
- `OCLW_CRYPTO_PLUGIN`: path al `.so` del proveedor.
- `OCLW_CRYPTO_SYMBOL`: simbolo a resolver; opcional.
  - Valor por defecto: `oclw_kpack_verify_v1`.

3. Firma C propuesta (version v1)
```c
int oclw_kpack_verify_v1(
  const char* signature_alg,
  const char* signer_id,
  const char* signature_value,
  const uint8_t* signing_text, size_t signing_text_len,
  const uint8_t* program_bin, size_t program_bin_len);
```
- Contrato de retorno:
  - `0` => verificacion OK.
  - `!= 0` => verificacion FAIL.

4. Mapeo a `Status_Code`
- Plugin ausente/no cargable/simbolo ausente -> `OCLW_SIGNATURE_NOT_IMPLEMENTED`.
- Plugin cargado pero retorno FAIL (`!= 0`) -> `OCLW_SIGNATURE_INVALID`.
- Plugin retorno OK (`0`) -> `Success`.

5. Politica RT (reafirmada)
- Si `signature_required=1`, la verificacion de firma es obligatoria.
- Si no hay plugin/verificador disponible o la verificacion falla:
  comportamiento fail-closed.
- En RT no hay fallback a source/JIT.

## Consequences

- Se desacopla la arquitectura RT de un proveedor criptografico concreto.
- Se habilita integracion incremental con proveedor aprobado sin romper el
  contrato de alto nivel.
- El comportamiento ante ausencia/fallo de proveedor queda determinista y
  trazable para V&V/CM.

## Alternatives Considered

1. Enlazar estaticamente un proveedor cripto unico
- Rechazada: acoplamiento temprano y menor portabilidad entre entornos.

2. Mantener solo verificador inyectable Ada
- Rechazada para RT operativo: no garantiza adopcion de proveedor aprobado.

3. Dejar politica de plugin solo como detalle de implementacion
- Rechazada: se necesita contrato auditable y estable desde arquitectura.

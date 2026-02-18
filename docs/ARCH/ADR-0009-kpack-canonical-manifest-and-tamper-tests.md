# ADR-0009: Kernel Pack Canonical Manifest and Tamper Tests

**ID:** OCLW-ADR-0009
**Status:** Accepted
**Date:** 2026-02-18
**Decision Makers:** <ARCHITECT_ROLE>, <VV_ROLE>, <CM_ROLE>, <RT_ROLE>
**References:** ADR-0008, <INDRA_INTERNAL_POLICY_REF>

## Context

G5 introduce flujo RT no-JIT con `manifest.kpack` + `program.bin`, verificacion de
fingerprint y hash de integridad. Para endurecer el control defense-grade se
requiere:
- serializacion canonical del manifiesto (determinista, auditable);
- parser estricto fail-closed;
- evidencia negativa obligatoria de deteccion de tamper;
- punto claro de integracion para firma/verificacion criptografica futura,
  sin acoplar dependencias nuevas en esta fase.

## Decision

1. Canonical manifest obligatorio
- El manifiesto canonical usa UTF-8 sin BOM y terminador de linea `LF` (`\n`).
- Cada linea es exactamente `key=value`.
- No se permiten espacios iniciales/finales en linea, clave o valor.
- No se permiten lineas vacias ni comentarios en la representacion canonical
  (solo en modo lectura tolerado para DEV si la politica local lo permite).
- Orden de claves fijo y obligatorio:
  1. `kpack_version`
  2. `pack_id`
  3. `created_utc`
  4. `platform_name`
  5. `platform_vendor`
  6. `platform_version`
  7. `device_name`
  8. `device_vendor`
  9. `device_version`
  10. `driver_version`
  11. `opencl_c_version`
  12. `build_options`
  13. `binary_size`
  14. `binary_fnv1a32`
  15. `kernel_name`

2. Politica de caracteres/escape
- Claves fuera del set canonical: rechazo.
- Valores deben ser UTF-8 valido y sin caracteres de control (`< 0x20`, excepto
  `space`) ni `DEL` (`0x7F`).
- Si un valor requiere caracteres no permitidos por esta politica, el pack se
  considera invalido (rechazo) o debe codificarse por mecanismo de escape
  definido y versionado por `kpack_version` (no se habilita escape libre ad-hoc).

3. Parse estricto y fail-closed
- Rechazar manifiesto por:
  - clave duplicada o desconocida;
  - clave faltante de campo requerido;
  - formato invalido (sin `=` unico, overflow numerico, `binary_size` invalido,
    `binary_fnv1a32` invalido, `kpack_version` invalido);
  - mismatch entre `binary_size` declarado y binario real;
  - mismatch de hash;
  - mismatch de fingerprint.
- En rechazo: fail-closed, sin fallback a source/JIT.

4. Evidencia negativa obligatoria (tamper tests)
- Gate de V&V debe incluir pruebas negativas con evidencia:
  - tamper de `program.bin` -> mismatch de hash;
  - tamper de fingerprint en `manifest.kpack` -> mismatch de fingerprint;
  - tamper de formato del manifiesto -> error de parse/pack format.
- El cierre de gate exige logs con `RESULT=PASS` para deteccion esperada del
  rechazo (es decir, el sistema detecta tamper correctamente).

5. Punto de integracion criptografica (futuro)
- Se define un punto de integracion por interfaz de verificacion de artefacto
  (`manifest + binario + metadata`) desacoplado del proveedor.
- En G6/G7 se conectara proveedor criptografico aprobado para firma/verificacion.
- Hasta entonces, FNV1a32 solo cubre integridad basica (no autenticidad).

## Consequences

- El pipeline DEV/CM debe producir manifiestos en forma canonical estable.
- RT obtiene comportamiento reproducible y auditable ante cambios/tamper.
- V&V gana criterios objetivos de aceptacion negativa (tamper detection).
- Queda trazado el hueco de autenticidad hasta integrar firma criptografica.

## Alternatives Considered

1. Manifest flexible (orden libre, espacios libres, parser tolerante)
- Rechazada: reduce determinismo y dificulta auditoria/forensia.

2. Solo pruebas positivas
- Rechazada: insuficiente para demostrar fail-closed ante tamper.

3. Introducir firma criptografica en este gate
- Postergada: requiere seleccion/validacion formal de proveedor aprobado y
  criterios de certificacion que se abordan en G6/G7.

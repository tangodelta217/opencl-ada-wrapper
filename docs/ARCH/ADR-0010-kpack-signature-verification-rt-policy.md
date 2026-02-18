# ADR-0010: Kernel Pack Signature Verification RT Policy

**ID:** OCLW-ADR-0010
**Status:** Accepted
**Date:** 2026-02-18
**Decision Makers:** <ARCHITECT_ROLE>, <VV_ROLE>, <CM_ROLE>, <RT_ROLE>, <SEC_ROLE>
**References:** ADR-0008, ADR-0009, <INDRA_INTERNAL_POLICY_REF>

## Context

G5/G6 consolidan no-JIT, manifest canonical y tamper detection por integridad.
Para perfil defense-grade falta cerrar autenticidad de artefactos
(`manifest.kpack` + `program.bin`) con una politica de firma verificable en
runtime RT.

## Decision

1. Campos de firma en `manifest.kpack`
- Se agregan los campos:
  - `signature_required` (`0`/`1`)
  - `signature_alg` (ejemplos: `CMS/PKCS7`, `ED25519`, `RSA-PSS-SHA256`, `TEST-FNV1A32`)
  - `signature` (codificacion **base64**)
  - `signer_id` (opcional)
  - `cert_fingerprint` (opcional)
- `signature` base64 se elige por interoperabilidad amplia con proveedores y
  formatos de firma; evita ambiguedad de mayusculas/minusculas de hex.

2. Canonical signing input
- La entrada firmada se construye sobre:
  - manifest canonical **sin** campos `signature_*` (`signature_required`,
    `signature_alg`, `signature`, `signer_id`, `cert_fingerprint`);
  - sin comentarios ni lineas en blanco;
  - `program.bin` como bytes crudos.
- Formato de bytes a firmar/verificar (V1):
  1. `OCLW-KPACK-SIG-V1\\n`
  2. `used=<decimal Used>\\n`
  3. bytes UTF-8 del manifest canonical (sin `signature_*`)
  4. `\\n--BIN--\\n`
  5. bytes de `program.bin[0 .. Used-1]`
- Si `binary_size` del manifest no coincide con `Used`, la verificacion falla
  antes de verificar firma.

3. Politica RT (fail-closed)
- Si `signature_required=1`, verificacion de firma es **obligatoria**.
- Si no se puede verificar (proveedor no disponible, algoritmo no soportado,
  firma invalida, metadata incompleta, cadena no valida), se rechaza carga:
  **fail-closed**.
- En RT no se permite fallback a source/JIT.

4. Politica DEV
- DEV/integracion puede generar packs sin firma (`signature_required=0`) o con
  firma de prueba (`signature_alg=TEST-FNV1A32`) segun politica del entorno.
- Artefactos para mision RT deben pasar por pipeline de release/CM con politica
  de firma aprobada.

5. Roadmap G8
- G8 integrara verificacion criptografica real con proveedor aprobado por
  politica del programa.
- Este ADR define contrato y comportamiento esperado; no fija implementacion
  criptografica especifica en esta fase.

## Consequences

- El manifest incluye metadatos explicitos de autenticidad auditables por CM/V&V.
- RT obtiene regla clara de rechazo seguro ante firma no verificable.
- Se separa claramente integridad (hash) de autenticidad (firma).
- Se habilita compatibilidad multi-proveedor via contrato de integracion.

## Alternatives Considered

1. No incluir `signature_required` en manifest
- Rechazada: dificulta gobernanza de transicion y enforcement por perfil.

2. Usar solo hash de integridad para autenticidad
- Rechazada: hash no autentica origen ni cadena de confianza.

3. Fijar un unico algoritmo en este gate
- Rechazada: acopla arquitectura antes de seleccionar proveedor cripto aprobado.

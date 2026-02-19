# ADR-0022: RT Crypto Plugin Allowlist and Permissions

**ID:** OCLW-ADR-0022  
**Status:** Accepted  
**Date:** 2026-02-19  
**Decision Makers:** <ARCHITECT_ROLE>, <SEC_ROLE>, <RT_ROLE>, <VV_ROLE>, <CM_ROLE>  
**References:** `docs/ARCH/Threat_Model_RT_Packs.md` (TM-T4, TM-G3),
ADR-0011, ADR-0012, ADR-0013, ADR-0020, `docs/ARCH/SDD.md`,
`docs/OPS/RT_Catalog_Playbook.md`

## Context

El threat model RT identifica:

- **TM-T4:** plugin substitution (backend `.so` no aprobado o manipulado).
- **TM-G3:** gap operativo en cadena de confianza del plugin (ruta/policy de
  filesystem y ownership no cerrados de forma explicita en runtime).

G10 introdujo checks minimos de confianza para plugin, pero en perfil
defense-grade RT strict se requiere una politica explicita de ubicacion
permitida (allowlist), junto con validaciones de tipo/permisos de archivo.

## Decision

1. Allowlist obligatoria de directorios en RT strict
- En RT strict, el plugin cripto solo puede cargarse desde directorios
  permitidos por allowlist canonical.
- Interfaz operativa:
  - `OCLW_RT_PLUGIN_ALLOWLIST="dir1:dir2:..."`
  - cada `dirN` se canonicaliza antes de validar.
- El path canonical del plugin debe quedar dentro de algun `dirN` canonical.
- Si la allowlist falta, esta vacia o es invalida en RT strict:
  fail-closed.

2. Politica de tipo de archivo y permisos minimos
- El plugin debe ser archivo regular.
- Se rechazan symlinks para el path final del plugin.
- Se rechaza plugin world-writable.
- El control de owner (uid/gid) se mantiene como hardening adicional:
  best-effort/futuro segun portabilidad/politica del target.

3. Dominio de errores
- Path fuera de allowlist: `OCLW_PLUGIN_PATH_NOT_ALLOWED`.
- Permisos inseguros (world-writable): `OCLW_PLUGIN_UNSAFE_PERMS`.
- Violaciones FS de symlink/no-regular pueden mapear a
  `OCLW_FS_POLICY_VIOLATION` (consistente con politica FS RT).
- `OCLW_PLUGIN_UNTRUSTED` puede mantenerse como estado agregado/compatibilidad
  para callers legacy.

4. Reglas de operacion RT
- En RT strict se mantiene configuracion explicita por API/config (`Configure_Plugin`).
- `OCLW_CRYPTO_PLUGIN`/`OCLW_CRYPTO_SYMBOL` permanecen fuera de confianza RT
  strict (DEV/integracion).
- El sistema debe fallar cerrado si no puede validar allowlist + permisos.

## Consequences

- Reduce riesgo de sustitucion de backend por path injection o despliegue fuera
  de baseline CM.
- Aumenta trazabilidad IV&V: el origen del plugin queda acotado a rutas
  aprobadas.
- Introduce requerimiento operativo adicional: provisionar allowlist en startup
  RT.

## Evidence (Gate G33)

Gate G33 debe incluir evidencia explicita:

- smoke: `smoke_rt_plugin_allowlist_policy`
- criterio minimo:
  - path fuera de allowlist rechazado (`OCLW_PLUGIN_PATH_NOT_ALLOWED`),
  - plugin con permisos inseguros rechazado (`OCLW_PLUGIN_UNSAFE_PERMS` o
    estado FS equivalente documentado),
  - caso valido dentro de allowlist y permisos correctos aceptado,
  - `RESULT=PASS`.

## Alternatives Considered

1. Permitir cualquier ruta absoluta con checks de permisos
- Rechazada: no cierra TM-G3 (sigue abierta superficie de sustitucion por ruta
  no aprobada).

2. Basarse solo en hash/firma del plugin
- No adoptada como control unico: util, pero no sustituye controles de ruta y
  permisos en runtime.

3. Exigir owner check estricto en todos los targets
- Parcialmente pospuesto: recomendado para produccion, pero puede no ser
  portable en todos los entornos de test/homelab.

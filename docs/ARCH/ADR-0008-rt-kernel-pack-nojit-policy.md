# ADR-0008: RT Kernel Pack No-JIT Policy

**ID:** OCLW-ADR-0008
**Status:** Accepted
**Date:** 2026-02-18
**Decision Makers:** <ARCHITECT_ROLE>, <VV_ROLE>, <CM_ROLE>, <RT_ROLE>
**References:** <INDRA_INTERNAL_POLICY_REF>

## Context

G4 confirma ruta funcional de program binaries para flujo no-JIT. En perfil
EW/Defense, el runtime debe priorizar determinismo, control de configuracion y
rechazo seguro ante mismatch de entorno o integridad.

La compilacion JIT en runtime introduce variabilidad de driver, dependencia de
filesystem/cache y comportamiento menos predecible para mision.

## Decision

1. No-JIT obligatorio en RT/EW
- En mision RT/EW no se permite build from source en runtime.
- Runtime solo carga artefactos precompilados aprobados (Kernel Pack).

2. Kernel Pack como artefacto de configuracion/CM
- El Kernel Pack (`manifest.kpack` + `program.bin`) es artefacto formal de
  release pipeline y baseline de configuracion.
- Su generacion queda en flujo offline controlado (DEV/Integracion/Release).

3. Verificacion estricta en runtime
- Antes de cargar, runtime debe validar:
  - Fingerprint minimo de plataforma/dispositivo/driver.
  - Integridad del binario contra metadatos (`binary_size` + hash declarado).
- Campos minimos de fingerprint: `platform_name`, `platform_vendor`,
  `platform_version`, `device_name`, `device_vendor`, `device_version`,
  `driver_version`.

4. Politica fail-closed
- Si hay mismatch de fingerprint, mismatch de hash/tamano, o metadata incompleta:
  - Rechazar carga de programa.
  - No usar fallback a source/JIT.
  - Retornar estado explicito para trazabilidad y V&V.

5. Hash actual y limitaciones
- `FNV1a32` se acepta en fase actual como verificacion de integridad
  no-criptografica (deteccion de corrupcion/cambio accidental).
- Para seguridad operacional completa, se requiere evolucion a hash
  criptografico y/o firma digital aprobada por politica.

## Alternatives Considered

1. Permitir JIT en RT como fallback.
- Rechazada: contradice politica no-JIT y reduce determinismo.

2. Validar solo version OpenCL sin fingerprint completo.
- Rechazada: insuficiente para controlar variabilidad real de driver/device.

3. Aceptar carga aunque falle hash/fingerprint con warning.
- Rechazada: no cumple criterio de fail-closed requerido en EW/Defense.

## Consequences

- Release pipeline/CM debe producir y versionar Kernel Packs por baseline HW/SW.
- Runtime debe mantener log de causa de rechazo para IV&V.
- V&V debe ampliar evidencia con casos de mismatch y rechazo controlado.
- Seguridad de artefactos queda parcialmente cubierta con `FNV1a32`; se planifica
  endurecimiento con mecanismos criptograficos en siguiente fase.

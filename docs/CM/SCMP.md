# Software Configuration Management Plan (SCMP)

**Proyecto:** OpenCL Ada Wrapper
**Referencia:** <INDRA_INTERNAL_POLICY_REF>

## 1. Objetivo
Definir las politicas de gestion de configuracion para el repositorio.

## 2. Estructura de Ramas
- `main`: rama estable de integracion.
- `feature/*`: ramas de desarrollo de funcionalidades.
- `hotfix/*`: correcciones urgentes sobre baseline.

## 3. Baselines
- Se establecera una baseline por release aprobado.
- Cada baseline debe tener:
  - Tag firmado/identificable.
  - Registro de cambios asociado.
  - Evidencias de pruebas en `docs/VV/Execution_Logs/`.

## 4. Releases
- Version semantica inicial: `<MAJOR>.<MINOR>.<PATCH>`.
- Cada release debe incluir:
  - ADRs relevantes.
  - Actualizacion de `docs/ARCH/SDD.md` si aplica.
  - SRS y SVVP actualizados si hay cambios de requisitos o verificacion.

## 5. Control de Cambios
- Cambios de API publica requieren ADR y actualizacion del SDD.
- No se introducen warnings nuevos sin justificacion escrita.


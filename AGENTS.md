# AGENTS.md

Instrucciones operativas y normas mínimas de ingeniería para Codex en este repo.

**Seguridad Operativa**
- No ejecutar comandos peligrosos ni destructivos (p. ej., `rm -rf /`, `git reset --hard`, `dd`).
- No usar modos sin aprobación explícita del usuario.
- No exfiltrar información; no pegar secretos en logs ni en respuestas.

**Reglas de Repositorio**
- Estructura de carpetas esperada: `docs/`, `src/`, `tests/`, `tools/`.
- Nomenclatura de IDs:
  - Requisitos: `OCLW-REQ-####`
  - Decisiones de arquitectura (ADR): `OCLW-ADR-####`
  - Tests: `OCLW-TST-####`
  - Riesgos: `OCLW-RSK-####`

**Normas de Cambio**
- Cada cambio de API pública debe actualizar `docs/ARCH/SDD.md` y crear un ADR en `docs/ADR/`.
- Toda funcionalidad nueva requiere al menos un test mínimo en `tests/` con ID `OCLW-TST-####`.

**Build y Estilo**
- Preferir Ada 2012/2022.
- Política de warnings: no introducir warnings nuevos sin justificar por escrito.

**Evidencias**
- Cada ejecución de test relevante debe documentarse en un log o en `docs/VV/Execution_Logs/`.

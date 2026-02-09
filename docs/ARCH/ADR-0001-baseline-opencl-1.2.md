# ADR-0001: Baseline OpenCL 1.2 con Capabilities (Mindset 3.0)
**ID:** OCLW-ADR-0001

**Estado:** Aprobado (baseline inicial)
**Fecha:** <YYYY-MM-DD>
**Decisor(es):** <ARCHITECT_ROLE>
**Referencias:** <INDRA_INTERNAL_POLICY_REF>

## Contexto
El wrapper Ada debe ser usable en entornos con drivers heterogeneos y soporte parcial de OpenCL.
Es necesario equilibrar compatibilidad amplia con un diseno moderno basado en capabilities.

## Decision
- Baseline funcional: OpenCL 1.2.
- "Mindset 3.0": capacidades detectables y habilitables explicitamente.
- La API no asume features fuera del baseline sin verificacion de capabilities.

## Alternativas Consideradas
1. Baseline OpenCL 2.x+.
2. Baseline OpenCL 1.2 con extensiones ad-hoc.
3. Baseline OpenCL 1.2 con enfoque de capabilities (seleccionada).

## Justificacion
- OpenCL 1.2 ofrece compatibilidad amplia en hardware legacy y drivers conservadores.
- El enfoque de capabilities reduce fallos en runtime y favorece determinismo.

## Consecuencias
- Funcionalidades avanzadas se exponen en la capa Optional y requieren gating explicito.
- La documentacion y pruebas deben detallar las capabilities requeridas.

## Impacto en Documentacion
- SDD debe describir la separacion por capas y el mecanismo de capabilities.
- SRS debe incluir requisitos de deteccion y manejo de capabilities.

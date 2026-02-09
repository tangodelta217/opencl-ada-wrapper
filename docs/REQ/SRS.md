# Software Requirements Specification (SRS)

**Proyecto:** OpenCL Ada Wrapper
**Referencias:** <INDRA_INTERNAL_POLICY_REF>

## 1. Proposito
Definir los requisitos funcionales y no funcionales del wrapper Ada de OpenCL.

## 2. Alcance
El sistema provee bindings y abstracciones Ada para OpenCL 1.2 con soporte de capabilities.

## 3. Definiciones y Acronimos
- OpenCL: Open Computing Language.
- Capability: Feature detectable y habilitable explicitamente.

## 4. Descripcion General
- Soporte de plataformas/disp. OpenCL 1.2.
- API segura en Ada con manejo explicito de errores.
- Subconjunto RT con restricciones de determinismo.

## 5. Requisitos

**OCLW-REQ-0001**
- **Texto:** El sistema debera exponer un conjunto completo de bindings 1:1 para la API OpenCL 1.2 en la capa Raw/Thin.
- **Verificacion:** Inspeccion.

**OCLW-REQ-0002**
- **Texto:** La capa Core/Thick debera proporcionar abstracciones Ada para contexto, cola de comandos, buffers y kernels.
- **Verificacion:** Inspeccion.

**OCLW-REQ-0003**
- **Texto:** El sistema debera detectar capabilities disponibles en tiempo de ejecucion y exponerlas mediante una API explicita.
- **Verificacion:** Test.

**OCLW-REQ-0004**
- **Texto:** Ninguna funcion Optional debera habilitarse sin verificacion previa de la capability correspondiente.
- **Verificacion:** Analisis.

**OCLW-REQ-0005**
- **Texto:** La capa Core/Thick debera traducir codigos de error OpenCL a un tipo Ada explicito (resultado o excepcion definida).
- **Verificacion:** Test.

**OCLW-REQ-0006**
- **Texto:** La capa RT no debera lanzar excepciones y debera usar resultados explicitos para errores.
- **Verificacion:** Inspeccion.

**OCLW-REQ-0007**
- **Texto:** La API publica debera permanecer compatible con Ada 2012/2022.
- **Verificacion:** Analisis.

**OCLW-REQ-0008**
- **Texto:** El sistema debera proveer un mecanismo de liberacion explicita de recursos para buffers y kernels.
- **Verificacion:** Test.

**OCLW-REQ-0009**
- **Texto:** El build no debera introducir warnings nuevos sin justificacion escrita.
- **Verificacion:** Inspeccion.

**OCLW-REQ-0010**
- **Texto:** Se debera mantener trazabilidad entre requisitos y pruebas en la documentacion de verificacion.
- **Verificacion:** Inspeccion.

## 6. Requisitos No Funcionales (Placeholder)
- <TBD_NFR_PERFORMANCE>
- <TBD_NFR_DETERMINISM>

## 7. Matriz de Trazabilidad (Placeholder)
- <TBD_TRACEABILITY_MATRIX>


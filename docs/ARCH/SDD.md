# Software Design Description (SDD)

**Proyecto:** OpenCL Ada Wrapper

## 1. Proposito y Alcance
Este documento describe la arquitectura por capas y el diseno de alto nivel del wrapper Ada para OpenCL.
Se enfoca en la estructura modular, responsabilidades y limites de cada capa, sin fijar implementaciones internas.

## 2. Supuestos y Restricciones
- Baseline OpenCL: 1.2 (ver ADR-0001).
- Lenguaje objetivo: Ada 2012/2022.
- No se introducen dependencias externas no justificadas.
- La arquitectura debe facilitar verificabilidad, trazabilidad y control de riesgos.

## 3. Vista de Capas

### 3.1 Raw / Thin Layer
**Rol:** Enlace directo con la API C de OpenCL (FFI).
**Responsabilidades:**
- Declaraciones `pragma Import` / bindings de simbolos OpenCL 1.2.
- Exponer funciones host minimas para enumeracion (`clGetPlatformIDs`,
  `clGetPlatformInfo`, `clGetDeviceIDs`, `clGetDeviceInfo`).
- Tipos equivalentes a los tipos C nativos (con alineacion/size controlados).
- Mapeo 1:1 de funciones sin logica adicional.
**No debe hacer:**
- Validacion de parametros, politica de errores ni gestion de recursos.

### 3.2 Core / Thick Layer
**Rol:** Capa principal de uso seguro.
**Responsabilidades:**
- Abstracciones Ada de contextos, colas, buffers y kernels.
- Gestion de recursos (RAII/control explicitado) y errores traducidos a tipos Ada.
- Validacion minima de precondiciones verificables.
- Conversion de strings, enums y bitfields a tipos Ada seguros.

### 3.3 RT Layer (Real-Time)
**Rol:** Subconjunto con garantias de determinismo y predictibilidad temporal.
**Responsabilidades:**
- API estable con restricciones explicitas (sin asignaciones ocultas, sin locks implicitos).
- Evitar operaciones potencialmente no deterministas o dependientes de drivers.
- Politica de error estricta (resultados explicitos, no excepciones).

### 3.4 Optional Layer
**Rol:** Extensiones no criticas o dependientes de capacidades.
**Responsabilidades:**
- Funcionalidades opcionales basadas en capabilities detectables.
- Soporte de extensiones/opt-ins con degradacion controlada.

## 4. Dependencias entre Capas
- Raw/Thin es la base y no depende de capas superiores.
- Core/Thick depende de Raw/Thin.
- RT depende de Core/Thick (o Raw/Thin cuando aplique), con restricciones adicionales.
- Optional depende de Core/Thick y/o Raw/Thin segun la feature.

## 5. Gestion de Errores
- Raw/Thin: retorna codigos/valores tal cual la API C.
- Core/Thick: convierte errores a tipos Ada (resultado o excepcion definida).
- RT: evita excepciones; usa `Result` explicito y codigos deterministas.

## 6. Capabilities y Versionado
- Baseline 1.2 con un "mindset 3.0": capacidades se detectan y habilitan explicitamente.
- El API expone capacidades como flags y no asume disponibilidad.

## 7. Trazabilidad de Requisitos
- Los requisitos funcionales y de calidad se enlazan desde `docs/REQ/SRS.md`.
- Cada modulo debe documentar la cobertura de requisitos y pruebas asociadas.

## 8. Seccion de Placeholder de Diagramas
- **Diagrama de capas:** <TBD_DIAGRAM_LAYERED_ARCH>
- **Diagrama de componentes Core:** <TBD_DIAGRAM_CORE_COMPONENTS>

## 9. Notas de Implementacion
- Priorizar interfaces pequenas, tipos fuertes y contratos claros.
- Evitar acoplarse a particularidades de drivers salvo en la capa Optional.

## 10. Estructura de Paquetes Base
- `src/opencl/opencl.ads` define el paquete raiz `OpenCL`.
- `src/opencl/raw/opencl-raw.ads` define el paquete padre `OpenCL.Raw`.
- `src/opencl/raw/opencl-raw-api.ads` define el thin binding `OpenCL.Raw.API`.
- Esta estructura fija el espacio de nombres publico inicial para evolucion incremental.

## 11. Build y Link
- Proyecto base (library): `opencl_wrapper.gpr`.
- Proyecto de tests: `tests/tests.gpr`.
- El link contra OpenCL se define por defecto con `-lOpenCL` en Linux.
- El valor de libreria se puede ajustar por variable de entorno `OPENCL_LIB_NAME`.
- El override avanzado se define por edicion del atributo `Linker_Options`
  en los archivos `.gpr`.

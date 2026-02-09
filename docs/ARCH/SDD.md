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
- Raw/Thin: retorna codigos/valores tal cual la API C (`cl_int`).
- Core/Thick: usa un modelo de estado explicito (codigo + `out` params) como via primaria.
- RT/EW: no usa excepciones como camino principal; solo resultados deterministas.
- Wrappers de conveniencia con excepciones (si se agregan) se limitan a tooling/no RT.

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
- El valor de link se puede ajustar por variable de entorno `OPENCL_LINK_FLAG`.
- En entornos no estandar puede usarse path absoluto a `libOpenCL.so`.

## 12. OpenCL.Errors
**Rol:** Modelo comun de errores para capa Core y consumidores de alto nivel.

**Que expone:**
- Tipo `Status_Code` (dominio numerico equivalente a `cl_int`).
- Constantes de estado relevantes para G0/G1 (`Success`, `Device_Not_Found`,
  `Platform_Not_Found_KHR`, `Unknown_Error` preservando codigo crudo).
- Funciones de conversion:
  - Raw -> Core (`cl_int` a `Status_Code`).
  - Core -> Raw (para passthrough/control de interoperabilidad).
- Utilidades de reporte determinista (texto estable para logs/V&V).

**Por que:**
- Evita mezclar enteros crudos en la capa Core.
- Mantiene trazabilidad ABI con el raw binding sin perder semantica OpenCL.
- Permite politicas uniformes de manejo de errores en paths RT/EW.
- Facilita pruebas de regresion textual y evidencia de gate.

## 13. OpenCL.Core (thick binding minimo)
**Objetivo:** Exponer una API de enumeracion util, verificable y determinista
sin introducir complejidad no necesaria para G0.

**13.1 Enumeracion de plataformas/dispositivos**
- API determinista (primaria): devuelve `Status_Code` + `out` params acotados.
- API convenience (secundaria): puede empaquetar resultados para tooling, pero
  sin reemplazar la API primaria ni RT/EW.
- Orden de salida estable para regresion textual:
  - Plataformas por `(Vendor, Name)`.
  - Dispositivos por `(Vendor, Name)`.

**13.2 Politica de strings/info**
- Toda consulta de info usa `size query` + clamp defensivo a `Max_Info_Bytes`.
- No se reservan buffers no acotados en stack por tamanos reportados por driver.
- Si el driver reporta tamanos excesivos, se limita/trunca y se deja advertencia.

**13.3 Casos esperados y manejo controlado**
- `CL_PLATFORM_NOT_FOUND_KHR`: se trata como "0 plataformas" en entorno valido
  sin ICD/plataformas; no es fallo catasrofico.
- `CL_DEVICE_NOT_FOUND`: se trata como "0 dispositivos" para la plataforma.
- Otros codigos != `CL_SUCCESS`: se reportan con codigo y contexto, continuando
  de forma controlada cuando sea posible.

**13.4 Politica de excepciones**
- No usar excepciones como camino principal en Core.
- Las excepciones, si existen en APIs de conveniencia futuras, se restringen a
  tooling/no RT y deben mapear 1:1 con `Status_Code`.

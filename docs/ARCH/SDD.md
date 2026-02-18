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
- Program/Kernel path: usa `Status_Code + Logs` (build log y mensajes de diagnostico acotados).
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

## 14. OpenCL.Core.Programs
**Objetivo:** Exponer ciclo minimo de programa OpenCL para integracion y diagnostico.

**14.1 Build desde source (dev/test path)**
- API para crear programa desde source en entorno de desarrollo/pruebas.
- Build options deben ser parametro explicito de API (sin defaults ocultos).
- Resultado de build siempre se reporta por `Status_Code`.

**14.2 Build log retrieval**
- El wrapper debe exponer recuperacion del build log por programa/dispositivo.
- Se define un limite explicito `Max_Build_Log_Bytes` para evitar reservas no acotadas.
- Politica de clamp:
  - Si el log reportado excede `Max_Build_Log_Bytes`, truncar de forma controlada.
  - Reportar estado y dejar traza de truncamiento en logs de V&V.

**14.3 Politica dev/test vs RT**
- **Nota explicita:** "Build from source = dev/test path; RT profile usara binaries".
- Perfil RT/EW no depende de compilador OpenCL en runtime; usara artefactos
  precompilados/validados del baseline.

**14.4 Casos esperados**
- `CL_COMPILER_NOT_AVAILABLE`: no crash; clasificar como caso controlado
  (`SKIP`) en smoke de compilacion, con evidencia explicita.

## 15. OpenCL.Core.Kernels
**Objetivo:** Exponer ejecucion minima de kernels para flujo host->device.

**15.1 Operaciones minimas**
- Crear kernel por nombre desde programa construido.
- Set de argumentos por `Address + Size` (wrappers tipados pueden agregarse despues).
- Enqueue NDRange 1D con tamanos de trabajo explicitos.
- Sincronizacion final por `Finish`.

**15.2 Politica de errores**
- Camino principal: `Status_Code` + informacion de diagnostico (sin excepciones).
- Fallos en create/set/enqueue/finish deben propagarse sin ambiguedad y con
  contexto minimo para IV&V.

## 16. Program binaries (RT path preliminar)
**Objetivo:** Definir estrategia no-JIT para perfil RT/EW usando programas
OpenCL precompilados/validados.

**16.1 Extraccion de binarios**
- En entorno dev/integracion se compila programa y se extraen binarios mediante
  APIs de `program_info` (tamano + contenido por dispositivo).
- El artefacto binario debe almacenarse junto con metadatos de fingerprint
  (plataforma, dispositivo, driver, version OpenCL C, opciones de build).
- La extraccion debe dejar evidencia reproducible para V&V.

**16.2 Creacion desde binario**
- La capa Core debe soportar creacion de programa desde binario
  (`Create_From_Binary`) como ruta principal para RT/EW.
- Tras crear desde binario se ejecuta validacion de build/estado por dispositivo
  y se reporta `Status_Code` explicito.
- No se asume compilador OpenCL disponible en runtime de mision.

**16.3 Build log + diagnostico**
- Aun en ruta de binario, el wrapper mantiene diagnostico acotado:
  estado de build, opciones efectivas y logs cuando el driver los provea.
- La politica de clamp de logs se mantiene para evitar reservas no acotadas.
- Los mensajes de error deben permanecer estables para regresion textual.

**16.4 Limitaciones y portabilidad**
- Los binarios OpenCL no se consideran portables por defecto entre
  vendor/driver/device.
- Un binario es valido solo para el fingerprint verificado del entorno objetivo.
- Si hay mismatch de fingerprint, la ruta RT debe fallar de forma controlada.

**16.5 Relacion con EW/RT**
- En mision EW/RT: politica no-JIT (sin build from source en runtime).
- Build from source queda restringido a flujo offline controlado de laboratorio.
- El pipeline de baseline debe incluir generacion, validacion y trazabilidad de
  binarios por configuracion de HW/SW aprobada.

## 17. RT Profile (EW/Defense): No-JIT mandatory
**Objetivo:** Fijar reglas operativas obligatorias para mision RT/EW.

**17.1 Politica obligatoria en runtime**
- En RT/EW, la compilacion JIT de kernels/programas esta prohibida.
- La ruta permitida es exclusivamente carga desde binario prevalidado
  (`Create_From_Binary` o equivalente).
- No se permite fallback automatico a source/JIT ante errores de carga.
- La validacion de artefacto debe incluir:
  - Verificacion de fingerprint del entorno objetivo.
  - Verificacion de integridad del binario por hash declarado.
- Ante mismatch o evidencia incompleta: comportamiento **fail-closed**
  (rechazar carga y devolver error explicito).

**17.2 DEV vs RT**
- DEV/Integracion:
  - Puede compilar desde source y generar Kernel Packs offline.
  - Debe registrar evidencia de build y metadatos para trazabilidad.
- RT/EW:
  - Solo consume Kernel Packs aprobados por pipeline de release/CM.
  - No genera binarios en runtime.

## 18. Kernel Pack (manifest + program.bin)
**Objetivo:** Estandarizar artefacto de despliegue no-JIT para RT/EW.

**18.1 Estructura minima de artefacto**
- `manifest.kpack`
- `program.bin`

**18.2 Formato de `manifest.kpack`**
- Texto UTF-8, una entrada por linea con formato `key=value`.
- Comentarios permitidos con prefijo `#`.
- Lineas vacias permitidas.
- Claves en minuscula con separador `_`.

**18.3 Campos minimos requeridos**
- `kpack_version`
- `pack_id`
- `created_utc`
- `platform_name`
- `platform_vendor`
- `platform_version`
- `device_name`
- `device_vendor`
- `device_version`
- `driver_version`
- `opencl_c_version` (opcional, recomendado)
- `build_options` (opcional)
- `binary_size`
- `binary_fnv1a32`
- `kernel_name`

**18.4 Politica de verificacion RT**
- Parse estricto de `manifest.kpack` y presencia de todos los campos requeridos.
- Verificar `binary_size` contra el tamano real de `program.bin`.
- Verificar `binary_fnv1a32` contra hash calculado del binario.
- Verificar fingerprint runtime (`platform_*`, `device_*`, `driver_version`)
  contra valores declarados en manifiesto.
- Si cualquier check falla: **fail-closed**.
- Fail-closed implica:
  - No cargar el programa.
  - No fallback a source/JIT.
  - Retornar estado explicito para log y V&V.

**18.5 Nota de seguridad/integridad**
- `FNV1a32` se usa como control de integridad no-criptografico (deteccion basica
  de corrupcion/cambio accidental).
- Para seguridad operacional real (anti-tamper/anti-spoof), se requiere hash
  criptografico y/o firma digital aprobada por politica (trabajo futuro).

## 19. Kernel Pack Canonical Manifest
**Objetivo:** Establecer serializacion determinista y auditable del manifiesto
del Kernel Pack.

**19.1 Reglas canonical**
- Codificacion: UTF-8 sin BOM.
- Terminador de linea: `LF` (`\n`) en todas las lineas.
- Formato de linea: exactamente `key=value`.
- Sin espacios iniciales/finales en linea, clave o valor.
- Sin lineas vacias ni comentarios en la representacion canonical.
- Orden de claves fijo y obligatorio:
  - `kpack_version`
  - `pack_id`
  - `created_utc`
  - `platform_name`
  - `platform_vendor`
  - `platform_version`
  - `device_name`
  - `device_vendor`
  - `device_version`
  - `driver_version`
  - `opencl_c_version`
  - `build_options`
  - `binary_size`
  - `binary_fnv1a32`
  - `kernel_name`

**19.2 Politica de caracteres**
- Rechazar claves fuera del conjunto canonical.
- Rechazar caracteres de control en valores (excepto `space`) y `DEL`.
- Rechazar manifiestos con UTF-8 invalido.
- Escape solo por esquema versionado explicito (`kpack_version`), nunca por
  reglas ad-hoc en runtime.

**19.3 Parse estricto**
- Rechazar manifest por clave faltante, clave duplicada, clave desconocida,
  formato invalido o conversion numerica invalida.
- Mantener fail-closed: si el parse no es 100% valido, no se carga programa.

## 20. RT Negative Testing (tamper detection)
**Objetivo:** Exigir evidencia negativa de deteccion de manipulacion en ruta RT.

**20.1 Casos negativos obligatorios**
- Tamper de binario (`program.bin`) -> hash mismatch detectado.
- Tamper de fingerprint en `manifest.kpack` -> fingerprint mismatch detectado.
- Tamper de formato manifest (claves invalidas/duplicadas/faltantes o sintaxis
  invalida) -> pack format error detectado.

**20.2 Criterio de aceptacion**
- La verificacion de gate debe incluir evidencia de los casos negativos con
  resultado esperado de rechazo controlado (fail-closed).
- El rechazo debe ser explicito y trazable por estado de error interno.

## 21. Kernel Pack Signature (Authenticity)
**Objetivo:** Definir politica de autenticidad para Kernel Pack en perfil RT.

**21.1 Campos de firma en manifest**
- `signature_required` (`0`/`1`)
- `signature_alg` (ejemplos: `CMS/PKCS7`, `ED25519`, `RSA-PSS-SHA256`,
  `TEST-FNV1A32`)
- `signature` (codificacion base64)
- `signer_id` (opcional)
- `cert_fingerprint` (opcional)

**21.2 Canonical signing input**
- Se firma/verifica el manifest canonical sin campos `signature_*` y sin
  comentarios/lineas vacias.
- Se concatena con bytes de `program.bin` y `Used` en formato estable:
  1. `OCLW-KPACK-SIG-V1\n`
  2. `used=<decimal Used>\n`
  3. bytes UTF-8 del manifest canonical sin `signature_*`
  4. `\n--BIN--\n`
  5. bytes `program.bin[0 .. Used-1]`
- Si `binary_size` no coincide con `Used`, la validacion falla.

**21.3 Politica RT**
- Si `signature_required=1`, verificar firma es obligatorio.
- Si no puede verificarse (firma invalida, metadata incompleta, proveedor no
  disponible o algoritmo no soportado), comportamiento **fail-closed**.
- No fallback a source/JIT en RT.

**21.4 Politica DEV**
- DEV/integracion puede generar packs sin firma (`signature_required=0`) o con
  firma de test, segun politica local.
- Para mision RT, pipeline release/CM debe entregar packs firmados segun
  politica aprobada.

## 22. Crypto Provider Plugin (C ABI) - Integration Point
**Objetivo:** Definir contrato de integracion defense-grade con proveedor
criptografico externo, desacoplado de implementacion especifica.

**22.1 Descubrimiento y carga de plugin**
- La integracion se define por plugin dinamico C ABI (`.so`) cargado via
  `dlopen`/`dlsym`.
- Variables de entorno:
  - `OCLW_CRYPTO_PLUGIN`: path al plugin compartido.
  - `OCLW_CRYPTO_SYMBOL`: simbolo de verificacion (opcional).
    - Default: `oclw_kpack_verify_v1`.
- Si el plugin no existe/no carga o el simbolo no se resuelve, se considera
  proveedor no implementado para el path de firma.

**22.2 Contrato C ABI (v1)**
- Firma propuesta:
```c
int oclw_kpack_verify_v1(
  const char* signature_alg,
  const char* signer_id,
  const char* signature_value,
  const uint8_t* signing_text, size_t signing_text_len,
  const uint8_t* program_bin, size_t program_bin_len);
```
- Semantica de retorno:
  - `0`: firma valida.
  - `!= 0`: firma invalida o no verificable por el proveedor.

**22.3 Mapeo a Status_Code del wrapper**
- Plugin ausente/no cargable/simbolo ausente ->
  `OCLW_SIGNATURE_NOT_IMPLEMENTED`.
- Plugin ejecutado y retorno `!= 0` -> `OCLW_SIGNATURE_INVALID`.
- Plugin ejecutado y retorno `0` -> `Success`.

**22.4 Reglas RT vs DEV**
- RT/EW:
  - Si `signature_required=1`, verificacion de firma obligatoria.
  - Si proveedor/verificador no esta disponible o la verificacion falla:
    fail-closed (rechazar carga).
  - No fallback a source/JIT.
- DEV/Integracion:
  - Puede usarse verificador inyectable de test para cobertura funcional.
  - Puede generarse pack sin firma solo cuando `signature_required=0`.
  - Validaciones de ruta RT deben registrar evidencia del plugin configurado.

**22.5 Roadmap**
- G8 integra verificacion real con proveedor criptografico aprobado usando este
  contrato C ABI.
- El verificador de test queda restringido a DEV/CI y no sustituye control
  criptografico operativo.

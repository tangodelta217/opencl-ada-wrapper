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

**16.6 IL path preparatorio (SPIR-V / `clCreateProgramWithIL`)**
- La capa thin declara `clCreateProgramWithIL` para habilitar preparacion
  progresiva de una futura ruta IL cuando el runtime la soporte.
- La capa core expone `Programs.Create_From_IL`, devolviendo `Status_Code`
  explicito del runtime (`CL_INVALID_OPERATION` esperado en runtimes sin soporte
  IL, sin excepciones).
- La validacion baseline usa smoke dedicado (`smoke_program_il_path`) con input
  dummy y resultado controlado:
  - `RESULT=SKIP` cuando IL no esta soportado o falla de forma esperada.
  - `RESULT=PASS` si el runtime acepta el path IL en el entorno bajo prueba.

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

## 23. RT Strict Policy (Post-G8)
**Objetivo:** Endurecer la politica RT/EW para eliminar ambiguedad operativa en
autenticidad de Kernel Packs.

**23.1 Firma obligatoria en RT**
- En RT/EW, `signature_required=1` es obligatorio.
- Packs con `signature_required=0` no son admisibles en despliegue RT.
- Si la politica no se cumple: fail-closed.

**23.2 Algoritmos de test prohibidos en RT**
- En RT/EW, `signature_alg` con prefijo `TEST-` esta prohibido.
- Esta prohibicion aplica aunque un backend tecnico pueda verificarlo.
- Si se detecta `TEST-*` en RT: fail-closed.

**23.3 Rationale defense/EW**
- RT de mision requiere autenticidad obligatoria, no opcional.
- Separar algoritmos de test de operacion reduce riesgo de configuracion
  indebida en despliegue.
- El perfil estricto reduce superficie de fallo silencioso y facilita auditoria
  IV&V/CM.

**23.4 Evidencia de gate**
- Gate G9 debe incluir evidencia positiva de politica estricta:
  `smoke_rt_strict_policy` con `RESULT=PASS`.

## 24. Secure configuration of crypto provider
**Objetivo:** Definir control de configuracion seguro del proveedor cripto en
perfil RT.

**24.1 Modelo preferido en RT**
- Preferir configuracion explicita por API/config gestionada por CM.
- Variables de entorno se consideran mecanismo de DEV/integracion; no control
  primario para despliegue RT operativo.

**24.2 Trusted path y control CM**
- El plugin/proveedor debe resolverse desde ruta confiable y de solo lectura.
- Ruta/version/hash del proveedor deben estar baselinados en artefactos CM.
- Debe validarse ownership/permisos del binario de proveedor antes de habilitar
  uso operacional.
- Se recomienda firma/verificacion del propio plugin dentro del pipeline.

**24.3 Politica de rechazo**
- Si no hay proveedor configurado de forma valida para RT, o la configuracion
  no cumple baseline CM, comportamiento fail-closed.

## 25. Trusted Crypto Provider Loading (RT)
**Objetivo:** Endurecer la carga dinamica del proveedor cripto en perfil RT con
controles minimos verificables y auditable por CM/IV&V.

**25.1 Ignorar env vars en RT estricto**
- En RT strict mode se ignoran `OCLW_CRYPTO_PLUGIN` y `OCLW_CRYPTO_SYMBOL`.
- Estas variables quedan permitidas solo para DEV/integracion.
- En RT, la seleccion de proveedor no puede depender del entorno del proceso.

**25.2 Configuracion explicita obligatoria**
- El proveedor debe configurarse explicitamente al arranque mediante
  `Configure_Plugin`.
- La ruta/simbolo deben provenir de configuracion controlada por CM
  (baseline release), no de entrada ad-hoc.

**25.3 Checks minimos del plugin**
- `path` absoluto.
- objetivo es archivo regular.
- archivo no world-writable.
- (opcional por politica del sistema) validar owner/permisos estrictos.

**25.4 Politica de rechazo**
- Si falla cualquiera de los checks anteriores, o no hay proveedor valido
  configurado cuando la firma es obligatoria: fail-closed.
- No fallback a source/JIT en RT.

## 26. Operational hardening checklist
**Objetivo:** Checklist operacional minima para despliegue RT del proveedor
cripto.

- Proveedor configurado por `Configure_Plugin` durante startup controlado.
- Ruta del plugin absoluta, fuera de directorios temporales/escribibles.
- Archivo plugin regular y no world-writable.
- Baseline CM incluye ruta, version y hash esperado del plugin.
- En RT strict mode, env vars `OCLW_CRYPTO_PLUGIN`/`OCLW_CRYPTO_SYMBOL`
  deshabilitadas/ignoradas.
- Fallo de carga/resolucion/verificacion del proveedor tratado como
  fail-closed.
- Evidencia de verificacion y configuracion registrada en logs de gate/V&V.

## 27. Profiling & Bench Harness
**Objetivo:** Definir infraestructura reproducible de medicion de performance
para soporte de budgets RT/EW y deteccion de regresiones.

**27.1 Metricas base**
- Tiempo host end-to-end por iteracion (incluye path host/device completo).
- Tiempo de ejecucion de kernel en dispositivo mediante event profiling cuando
  el driver/cola lo soporta.
- Export de datos crudos por iteracion en CSV para analisis posterior.

**27.2 Reglas de ejecucion**
- Warm-up obligatorio antes de medir.
- Repeticiones N fijas por benchmark para reducir varianza.
- Salida textual estable orientada a evidencia V&V (`RESULT`, percentiles,
  estado de profiling).

**27.3 Estadisticos requeridos**
- `min`, `avg`, `p50`, `p95`, `p99`.
- Los percentiles altos (`p95/p99`) son indicadores primarios para control de
  cola de latencia en contexto RT.

**27.4 Politica ante profiling no disponible**
- Si profiling por eventos no esta disponible, benchmark continua con metrica
  host y reporta `profiling=UNAVAILABLE`.
- El estado se reporta via `Status_Code` explicito; no se usan excepciones como
  camino principal.

**27.5 Alcance de representatividad**
- Resultados en homelab/CI/DEV no se consideran validacion final de budget en
  target operacional.
- Su uso principal es regression tracking y salud del stack entre gates.

## 28. G13a.1 RT Pack E2E Benchmark
**Objetivo:** Medir la ruta RT real basada en Kernel Packs (no-JIT) en dos
fases: inicializacion cold y ejecucion steady-state.

**28.1 Diseno de `bench_rt_pack_add1`**
- Fase A: RT init cold (single-shot)
  - Carga de `manifest.kpack` + `program.bin` desde `OCLW_PACK_DIR`.
  - Verificacion RT obligatoria del pack (formato, fingerprint, hash y firma
    segun politica vigente).
  - Creacion de programa desde binario (`Create_From_Binary`), build y setup de
    kernel/args.
  - Medicion de latencia host de inicializacion.
- Fase B: RT steady-state (W+N iteraciones)
  - Iteraciones de write/enqueue/read sobre programa ya cargado.
  - Warm-up `W` para estabilizar mediciones.
  - Medicion `N` para estadisticos finales.
  - Si profiling por eventos disponible: incluir metricas device por iteracion.
- Salida estable:
  - `INFO cold_init_ns=...`
  - `INFO host_ns_p50=...`, `INFO host_ns_p95=...`, `INFO host_ns_p99=...`
  - `INFO device_ns_p50=...`, `INFO device_ns_p95=...`, `INFO device_ns_p99=...`
    cuando aplique.
  - `RESULT=PASS|FAIL|SKIP`.

**28.2 Variables de entorno esperadas**
- `OCLW_PACK_DIR`: directorio del pack RT a cargar.
- `OCLW_BENCH_WARMUP`: cantidad de iteraciones warm-up (default del bench).
- `OCLW_BENCH_ITERS`: cantidad de iteraciones de medicion (default del bench).
- `OCLW_CRYPTO_PLUGIN`: ruta del plugin de verificacion (DEV/integracion).
- `OCLW_CRYPTO_SYMBOL`: simbolo C ABI del plugin (default de integracion).
- En RT strict mode, el uso de env vars para plugin puede estar deshabilitado
  por politica; el benchmark debe reflejar la politica activa.

**28.3 Ejecucion y evidencia**
- Ejecucion directa:
  - `./tests/bin/bench_rt_pack_add1`
- Ejecucion via harness:
  - `tools/run_smoke.sh` (cuando el gate lo incluya en el run list).
- Evidencia local de apoyo:
  - `docs/VV/Execution_Logs/local/` (CSV y logs de bench).
- Evidencia oficial de gate:
  - `docs/VV/Execution_Logs/GATES/G13A1/rerun_01/` con reporte consolidado y
    extractos de metricas.

**28.4 Criterio de interpretacion**
- Los numeros de G13a.1 fuera de target se usan para regression tracking.
- La aceptacion de budgets operacionales requiere ejecucion en HW/driver target
  (FPGA/GPU y baseline software congelado por CM).

## 29. Multi-device program binaries
**Objetivo:** Definir uso correcto de binarios de programa cuando un
`cl_program` esta asociado a N dispositivos (OpenCL 1.2).

**29.1 Modelo OpenCL aplicable**
- `CL_PROGRAM_NUM_DEVICES` define cuantos dispositivos estan asociados al
  programa.
- `CL_PROGRAM_BINARY_SIZES` devuelve arreglo de `size_t` por dispositivo.
- `CL_PROGRAM_BINARIES` devuelve arreglo de punteros a buffers por dispositivo.
- El indice de cada entrada corresponde al orden de dispositivos asociado al
  `cl_program`.

**29.2 API esperada en `Core.Programs`**
- Consulta de cantidad de dispositivos (`num_devices`) del programa.
- Consulta de `binary_size` por indice de dispositivo.
- Obtencion de binario por indice de dispositivo.
- Opcion para recuperar arreglos completos (`sizes[]` + `binaries[]`) cuando el
  caller aporta buffers y capacidades.

**29.3 Reglas de contrato**
- Indice fuera de rango -> `Status_Code` explicito.
- Capacidad insuficiente de buffer -> `Status_Code` explicito.
- Sin excepciones como camino principal.
- En camino RT: sin asignaciones ocultas; el caller controla memoria.

**29.4 Trazabilidad y evidencia**
- Los logs/smokes que extraigan binarios multi-device deben registrar:
  - `num_devices`,
  - indice probado,
  - `binary_size` por indice,
  - fingerprint del dispositivo efectivo.
- La evidencia de gate debe permitir reconstruir que binario corresponde a cada
  device index.

## 30. RT policy: single vs multi-device
**Objetivo:** Fijar politica determinista para RT cuando el entorno puede
exponer varios dispositivos.

**30.1 Politica RT strict por defecto**
- RT strict ejecuta sobre exactamente un dispositivo validado.
- Si el entorno expone N>1 dispositivos, se permite:
  - exigir exactamente 1 dispositivo elegible tras filtro/fingerprint, o
  - seleccionar exactamente 1 dispositivo de forma determinista (regla estable
    y auditable) y validar fingerprint completo.
- Si existe ambiguedad o mismatch: fail-closed.

**30.2 Politica DEV/integracion**
- DEV puede operar con N dispositivos y consumir arreglos completos de binarios
  para diagnostico, comparacion y preparacion offline.
- El soporte multi-device en DEV no relaja restricciones RT strict de despliegue.

**30.3 Criterio de evidencia G14**
- Escenario base obligatorio: gate en entorno de 1 dispositivo con `RESULT=PASS`.
- Si hay >=2 dispositivos disponibles en el sistema:
  - ejecutar smoke multi-device y validar indices/sizes/binaries por device.
- Si no hay >=2 dispositivos:
  - marcar parte multi-device como `SKIP` controlado con razon explicita.

## 31. Parser robustness & fuzzing
**Objetivo:** Asegurar robustez del parser `manifest.kpack` con enfoque
fail-closed y comportamiento acotado.

**31.1 Propiedades obligatorias**
- No crash ante entradas validas o malformadas.
- Fail-closed ante cualquier desviacion de formato, limite o consistencia.
- Sin truncado silencioso en parser de manifest.

**31.2 Limites estrictos del parser**
- El parser debe operar con limites explicitos:
  - `max_manifest_bytes`,
  - `max_lines`,
  - `max_keys`,
  - `max_key_len`,
  - `max_value_len`.
- Si se excede cualquier limite:
  - devolver `Status_Code` explicito de error interno,
  - rechazar el pack,
  - continuar sin excepciones como camino principal.

**31.3 Estrategia de fuzzing**
- Corpus versionado de manifest malformados base.
- Mutacion pseudoaleatoria determinista con seed reproducible.
- Presupuesto de corrida de smoke orientativo:
  - 2 segundos o 2000 casos por ejecucion.
- Si se corta por tiempo, reportar contadores reales y razon.

**31.4 Reproducibilidad de incidentes**
- Ante fallo inesperado, guardar input exacto y metadatos:
  - seed,
  - iteracion,
  - timestamp/entorno basico.
- El artefacto debe permitir replay determinista del caso.

**31.5 Evidencia de gate**
- G15 debe incluir `smoke_fuzz_kpack_parser` con:
  - `RESULT=PASS` (no crash),
  - contadores de ejecucion (casos totales, rechazos esperados, errores
    inesperados, tiempo total, seed).

## 32. Memory discipline (No heap after init)
**Objetivo:** Garantizar que el steady-state RT/EW no realiza asignaciones de
heap y que la politica se puede verificar en runtime.

**32.1 Requisito operacional**
- En modo RT strict, una vez completada la fase de init, no se permiten nuevas
  asignaciones dinamicas.
- La fase de init define explicitamente la unica ventana permitida de heap.

**32.2 Mecanismo de instrumentacion**
- Instrumentar asignaciones mediante:
  - storage pool fijo/acotado para rutas RT,
  - contador de asignaciones (`alloc_count`) para trazabilidad,
  - operacion `Freeze_Allocations` que cierra la ventana de heap.
- Tras `Freeze_Allocations`, cualquier alloc se registra como violacion de
  politica.

**32.3 Politica DEV vs RT strict**
- DEV/Integracion:
  - puede usar heap para tooling/diagnostico,
  - debe reportar `alloc_count` y eventos post-freeze en logs.
- RT strict:
  - requiere `Freeze_Allocations` antes de steady-state,
  - alloc post-freeze => fail-closed con `Status_Code` interno explicito.

**32.4 Criterio de evidencia**
- Gate G17 debe incluir smoke dedicado `smoke_rt_no_heap_after_init` con:
  - `RESULT=PASS`,
  - evidencia de init permitida,
  - evidencia de freeze aplicado,
  - evidencia de rechazo controlado ante alloc post-freeze en RT strict.

## 33. RT build options policy (strict allowlist)
**Objetivo:** Reducir variabilidad y riesgo operativo en RT strict limitando
las opciones de compilacion admitidas al cargar Kernel Packs.

**33.1 Politica minima**
- En `Create_Program_From_Pack_Strict_RT`, `build_options` debe pasar una
  allowlist estricta:
  - `""` (vacio)
  - `"-cl-std=CL1.2"`
- Cualquier otra combinacion se rechaza con fail-closed.

**33.2 Denylist explicita (defense-oriented)**
- Se consideran no admisibles en RT strict (entre otras):
  - flags con prefijo `-I`
  - flags con prefijo `-D`
  - `-cl-opt-disable`
- La denylist se evalua antes de construir el programa en RT strict.

**33.3 DEV vs RT**
- DEV/integracion:
  - no se aplica esta restriccion en `Create_Program_From_Pack` (no strict).
  - puede explorar opciones de build para diagnostico/controlado.
- RT strict:
  - aplica allowlist obligatoria.
  - mismatch -> `OCLW_BUILD_OPTIONS_DISALLOWED`.

**33.4 Evidencia de gate**
- Gate G22 debe incluir smoke `smoke_rt_build_options_policy` con:
  - caso allow (`-cl-std=CL1.2`) -> PASS,
  - caso deny (ej. `-cl-opt-disable`) -> rechazo esperado
    `OCLW_BUILD_OPTIONS_DISALLOWED`,
  - `RESULT=PASS` global del smoke.

## 34. Deterministic Device Selection and Pack Catalog
**Objetivo:** Soportar multiples fingerprints aprobados (fat pack) sin
recompilar en mision, manteniendo determinismo RT y fail-closed.

**34.1 Seleccion determinista de device**
- Construir lista de candidatos con fingerprint completo:
  - `platform_vendor`, `platform_name`, `platform_version`
  - `device_vendor`, `device_name`, `device_version`, `driver_version`
- Aplicar orden determinista:
  1. `device_vendor` (asc)
  2. `device_name` (asc)
  3. `driver_version` (asc)
  4. `platform_vendor` (asc)
  5. `platform_name` (asc)
  6. desempate por indices de enumeracion (`platform_index`, `device_index`).
- Reglas de preferencia:
  - Si existe politica de preferencia explicitamente configurada y aprobada por
    CM (vendor/device), se aplica antes del orden lexicografico.
  - Sin politica explicita, se usa solo el orden determinista.

**34.2 Estructura de Pack Catalog (fat pack)**
- Un catalogo es un directorio con N subpacks:
  - `<catalog_root>/<subpack_001>/manifest.kpack`
  - `<catalog_root>/<subpack_001>/program.bin`
  - ...
- Cada subpack es autocontenido para un fingerprint objetivo.
- Orden de evaluacion:
  - indice de catalogo aprobado por CM (si existe), o
  - orden lexicografico por subdirectorio.

**34.3 Seleccion de subpack**
- Con el dispositivo ya seleccionado, el loader recorre subpacks en orden
  determinista.
- Regla de aceptacion:
  - primer subpack con fingerprint exacto -> candidato valido.
- Verificaciones del candidato:
  - parse canonical estricto del manifest,
  - hash/integridad de `program.bin`,
  - firma de subpack.
- Si no hay match exacto o falla cualquier verificacion: fail-closed.

**34.4 Firma por-subpack**
- La firma se define por subpack (no firma global unica del catalogo):
  - `signature_required`
  - `signature_alg`
  - `signature_value`
  - `signer_id` (opcional)
- El signing input se calcula por subpack:
  - manifest canonical sin campos `signature_*`,
  - concatenado con `program.bin` del mismo subpack.
- Consecuencia:
  - cada subpack puede estar firmado por pipeline/clave aprobada sin mezclar
    validez entre fingerprints distintos.

**34.5 Politica RT**
- RT strict:
  - no fallback a source/JIT,
  - no match de fingerprint en catalogo -> fail-closed,
  - subpack candidato con firma/hash/format invalido -> fail-closed.
- DEV/integracion:
  - permite diagnostico de catalogo multi-subpack,
  - no relaja politica strict de produccion.

**34.6 Evidencia de gate**
- Gate G24 requiere smoke `smoke_pack_catalog_selection` con:
  - `RESULT=PASS`,
  - evidencia de orden determinista de seleccion,
  - subpack seleccionado (o no-match controlado segun caso de prueba).

**34.7 Mapeo de API**
- Seleccion determinista de dispositivo:
  - `OpenCL.Core.Device_Selection.Select_Device`.
- Seleccion de subpack desde catalogo:
  - `OpenCL.RT.Catalog.Load_From_Catalog`.
- Integracion RT:
  - `OpenCL.RT.Loader.Select_Device` reutiliza seleccion determinista para
    match exacto de fingerprint.

## 35. RT Loader FS Policy
**Objetivo:** Endurecer la carga de `manifest.kpack` y `program.bin` frente a
ataques de filesystem (symlink/path traversal) en RT strict.

**35.1 Boundary y amenazas**
- Boundary operativo: `pack_dir` configurado para runtime RT.
- Amenazas cubiertas:
  - symlink redirection de `manifest.kpack`/`program.bin`,
  - path traversal/escape del directorio aprobado.
- Referencia de threat model:
  - `TM-T3` y gap `TM-G1` en `docs/ARCH/Threat_Model_RT_Packs.md`.

**35.2 Politica de symlink**
- En RT strict, `manifest.kpack` y `program.bin` deben ser archivos regulares.
- Si alguno es symlink: rechazo inmediato fail-closed.
- No se admite excepcion por symlink "interno" al mismo arbol.

**35.3 Politica de path canonical**
- `pack_dir` se canonicaliza al inicio del flujo de carga.
- Los paths efectivos de `manifest.kpack` y `program.bin` deben resolver dentro
  del prefijo canonical de `pack_dir`.
- Se rechaza cualquier intento de escape por `..`, resolucion indirecta o
  errores de canonicalizacion.
- En RT strict, el loader no acepta rutas arbitrarias para artefactos del pack:
  solo nombres canonicos esperados bajo `pack_dir`.

**35.4 Dominio de errores**
- Violaciones de politica FS se reportan con estado interno dedicado:
  `OCLW_FS_POLICY_VIOLATION`.
- Objetivo: separacion clara entre error de policy de filesystem y error de
  formato de manifest (`OCLW_PACK_FORMAT_ERROR`).
- En todos los casos el comportamiento es fail-closed.

**35.5 Evidencia de gate**
- Gate G31 debe incluir smoke negativo dedicado:
  - `smoke_rt_pack_symlink_escape`
  - `RESULT=PASS`
- Cobertura minima:
  - symlink en `manifest.kpack` rechazado,
  - symlink en `program.bin` rechazado,
  - escape de path rechazado con status de policy FS (o mapping fail-closed
    documentado).

## 36. TOCTOU Mitigation
**Objetivo:** Mitigar condiciones de carrera de tipo verify-then-replace
(TOCTOU) durante la carga RT de `manifest.kpack` y `program.bin`.

**36.1 Threat mapping y alcance**
- Amenaza principal: `TM-T7` (TOCTOU).
- Gap asociado: `TM-G2`.
- Referencia: `docs/ARCH/Threat_Model_RT_Packs.md`.
- Relacion con G31:
  - G31 cubre path safety (symlink/traversal),
  - esta seccion cubre seguridad temporal del archivo durante lectura.

**36.2 Flujo por descriptor (lectura consistente)**
- En RT strict, la lectura de cada archivo se diseña por FD:
  - `open()` del archivo esperado,
  - `fstat()` pre,
  - `read()` desde el mismo FD,
  - `fstat()` post.
- No se permite reabrir por path durante la secuencia de validacion y carga.

**36.3 Invariantes de seguridad**
- Entre `fstat` pre y post deben mantenerse:
  - tipo regular (`S_IFREG`),
  - `inode` estable,
  - `size` estable.
- Si cualquier invariante falla:
  - status `OCLW_FS_TOCTOU_DETECTED`,
  - fail-closed (sin fallback a source/JIT).

**36.4 Test seam para pruebas deterministas**
- Se permite seam de test para forzar swap controlado entre `fstat` pre/post.
- Requisito:
  - seam solo habilitado en builds/tests de verificacion,
  - no disponible en release de produccion.
- Implementacion:
  - controles de seam mantenidos como hooks privados en `OpenCL.RT.FS`,
  - uso permitido solo desde child units de test
    (`tests/smoke/opencl-rt-fs-test_seam.*`),
  - no API publica de seam en artefacto release.

**36.5 Evidencia de gate**
- Gate G32 debe incluir:
  - `smoke_rt_toctou_manifest_swap`,
  - `smoke_rt_toctou_binary_swap`.
- Criterio minimo:
  - deteccion de swap y rechazo fail-closed,
  - `RESULT=PASS`,
  - trazas con `OCLW_FS_TOCTOU_DETECTED`.

## 37. RT plugin policy (allowlist/perms)
**Objetivo:** Endurecer la carga del provider cripto en RT strict con politica
explicita de rutas permitidas y permisos minimos de filesystem.

**37.1 Threat mapping**
- Amenaza principal: `TM-T4` (plugin substitution).
- Gap asociado: `TM-G3`.
- Referencia: `docs/ARCH/Threat_Model_RT_Packs.md`.

**37.2 Allowlist de directorios canonical**
- En RT strict, el plugin solo puede cargarse desde una allowlist de
  directorios canonical.
- Interfaz operativa:
  - `OCLW_RT_PLUGIN_ALLOWLIST="dir1:dir2:..."`
- Reglas:
  - cada entrada `dirN` se canonicaliza,
  - el path canonical del plugin debe quedar contenido en algun `dirN`
    canonical.
- Si la allowlist falta o es invalida en RT strict: fail-closed.

**37.3 Checks de tipo/permisos del plugin**
- El plugin debe ser archivo regular.
- Symlinks rechazados en RT strict.
- Archivo world-writable rechazado.
- Owner check (`uid/gid`) se recomienda como hardening adicional
  best-effort/politica de plataforma.

**37.4 Dominio de errores**
- Path fuera de allowlist: `OCLW_PLUGIN_PATH_NOT_ALLOWED`.
- Permisos inseguros: `OCLW_PLUGIN_UNSAFE_PERMS`.
- Symlink/no-regular: `OCLW_FS_POLICY_VIOLATION` (o mapping equivalente
  documentado).
- Todos los casos anteriores se tratan como fail-closed.

**37.5 Operacion RT vs DEV**
- RT strict:
  - configuracion explicita via `Configure_Plugin`,
  - allowlist obligatoria y validada,
  - sin fallback a source/JIT.
- DEV/integracion:
  - puede usar rutas de test/controladas fuera de politica estricta,
  - debe dejar evidencia explicita de ruta/permisos del plugin usado.

**37.6 Evidencia de gate**
- Gate G33 debe incluir `smoke_rt_plugin_allowlist_policy` con:
  - rechazo fuera de allowlist,
  - rechazo por permisos inseguros,
  - aceptacion del caso valido,
  - `RESULT=PASS`.

## 38. EW MLP Demo (Quantized, deterministic)
**Objetivo:** Incorporar un demostrador tecnico EW/RT de inferencia MLP
determinista, con trazabilidad y evidencia reproducible.

**38.1 Alcance funcional del demo**
- Topologia MLP de referencia:
  - entrada `64`,
  - capa oculta `96`,
  - salida `4`,
  - activacion ReLU.
- Aritmetica `int-only` para reducir variabilidad numerica y facilitar
  comparacion exacta.
- Dataset sintetico deterministico de 4 clases por banda (no sensible).

**38.2 Encaje DEV vs RT**
- DEV (build-from-source):
  - permite generar artefactos y validar funcionalidad durante desarrollo.
  - puede usar compilacion desde source para preparar `program.bin`.
- RT (no-JIT):
  - ejecuta desde Kernel Pack (`manifest.kpack` + `program.bin`).
  - no permite fallback a source.
  - aplica checks de hash/fingerprint/firma/politicas RT strict segun gates
    vigentes.

**38.3 Determinismo y correctitud**
- Determinismo por diseno:
  - datos de entrada sinteticos y reproducibles,
  - pesos/sesgos deterministas,
  - aritmetica entera.
- Correctitud objetivo:
  - salida bit-exact CPU vs OpenCL para las mismas entradas.
- Salida operacional:
  - `RESULT=PASS|FAIL|SKIP`,
  - `INFO ...` acotado y parseable.

**38.4 Bench y evidencia minima**
- El demo debe reportar metricas minimas:
  - latencia `p50`/`p99`,
  - throughput.
- Evidencia esperada en VV:
  - build + smoke/demo logs,
  - extractos de correctitud y metricas.

**38.5 Trazabilidad**
- Requisitos asociados:
  - `OCLW-REQ-0401` correctitud bit-exact,
  - `OCLW-REQ-0402` ruta RT no-JIT desde binario,
  - `OCLW-REQ-0403` salida estable defense-friendly,
  - `OCLW-REQ-0404` benchmark minimo.
- Tests planificados:
  - `OCLW-TST-0401` `smoke_ew_mlp_inference`,
  - `OCLW-TST-0402` `smoke_rt_load_pack_ew_mlp`,
  - `OCLW-TST-0403` `bench_rt_pack_ew_mlp`.

# Risk Register

**Proyecto:** OpenCL Ada Wrapper
**Referencia:** <INDRA_INTERNAL_POLICY_REF>

| ID | Riesgo | Prob. | Impacto | Mitigacion | Owner | Estado |
| --- | --- | --- | --- | --- | --- | --- |
| OCLW-RSK-0001 | Variabilidad de drivers OpenCL entre vendors | Media | Alta | Baseline 1.2 + capabilities explicitas; pruebas en multiples entornos | <TBD_OWNER> | Abierto |
| OCLW-RSK-0002 | Falta de determinismo en ejecucion | Media | Alta | Definir capa RT con restricciones; pruebas de tiempo y trazas | <TBD_OWNER> | Abierto |
| OCLW-RSK-0003 | Dependencia de COTS (drivers/SDK) sin control de ciclo de vida | Media | Media | Documentar versiones soportadas; matriz de compatibilidad | <TBD_OWNER> | Abierto |
| OCLW-RSK-0004 | Incompatibilidad ABI/FFI en bindings | Baja | Alta | Validar tipos y tamanos; pruebas de conformidad | <TBD_OWNER> | Abierto |
| OCLW-RSK-0005 | Deteccion incorrecta de capabilities | Baja | Alta | Tests de enumeracion y validacion en runtime | <TBD_OWNER> | Abierto |
| OCLW-RSK-0006 | Performance insuficiente por sobrecarga de abstracciones | Media | Media | Medicion de overhead; opcion de usar Raw/Thin | <TBD_OWNER> | Abierto |
| OCLW-RSK-0007 | Dev environment without OpenCL ICD/platforms | Media | Media | Ejecutar smoke en pre-check de entorno; documentar fallback controlado (`CL_PLATFORM_NOT_FOUND_KHR`); para Gate G2 exigir al menos 1 plataforma valida en entorno de integracion | <TBD_OWNER> | Abierto |
| OCLW-RSK-0008 | Dependencia de ICD/driver (COTS) para ejecucion real | Media | Alta | Mantener fingerprint de plataforma/dispositivo por baseline (`docs/HW/Platform_Fingerprint.md`); ejecutar banco HW multi-ICD; controlar versionado de drivers/ICD en entornos de integracion | <TBD_OWNER> | Abierto |
| OCLW-RSK-0009 | JIT compilation requires writable temp/cache; sandboxed/locked-down environments may fail builds | Media | Alta | En test harness fijar `POCL_CACHE_DIR` a ruta writable en workspace (`tools/run_smoke.sh`); para perfil RT/EW preferir binaries precompilados (sin JIT) | <TBD_OWNER> | Abierto |

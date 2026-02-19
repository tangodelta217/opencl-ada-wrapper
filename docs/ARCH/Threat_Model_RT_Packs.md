# Threat Model: RT Loader / Kernel Pack / Crypto Plugin

**Proyecto:** OpenCL Ada Wrapper (INDRA/EW)  
**Estado:** Working baseline threat model (post G30)  
**Fecha:** 2026-02-19  
**Alcance:** Ruta RT no-JIT para `manifest.kpack` + `program.bin` + verificacion de firma por plugin.

## 1. Activos protegidos

| Asset ID | Activo | Motivo de proteccion |
| --- | --- | --- |
| TM-A1 | Integridad de `program.bin` | Evitar ejecucion de kernel alterado. |
| TM-A2 | Integridad/correccion de `manifest.kpack` | Evitar bypass de politica RT o metadatos falsos. |
| TM-A3 | Fingerprint de plataforma/device/driver | Evitar cargar binarios fuera de baseline validado. |
| TM-A4 | Politica RT strict (`signature_required`, no-JIT, fail-closed) | Evitar degradacion a modos no aprobados. |
| TM-A5 | Verificacion de firma/autenticidad | Garantizar origen confiable del pack. |
| TM-A6 | Cadena de confianza del plugin de verificacion | Evitar plugin sustituido/malicioso. |
| TM-A7 | Estado anti-rollback (contador monotono) | Evitar carga de versiones antiguas vulnerables. |
| TM-A8 | Determinismo operacional (sin dependencias ambient no controladas) | Evitar variabilidad/no determinismo en mision. |

## 2. Superficies de ataque (practicas)

| Threat ID | Superficie/Vector | Escenario de ataque | Impacto |
| --- | --- | --- | --- |
| TM-T1 | Manifest tampering | Alterar `signature_required`, `signature_alg`, fingerprint o campos de tamano/hash. | Bypass de controles o rechazo no determinista. |
| TM-T2 | Binary tampering | Modificar bytes de `program.bin` manteniendo estructura de pack. | Ejecucion de codigo no autorizado. |
| TM-T3 | Path traversal / symlink en `pack_dir` | Resolver `manifest.kpack`/`program.bin` a rutas fuera del staging esperado. | Lectura de artefacto no autorizado. |
| TM-T4 | Plugin substitution (untrusted) | Sustitucion del `.so` por backend no aprobado o con permisos inseguros. | Verificacion de firma comprometida. |
| TM-T5 | Rollback | Cargar pack antiguo con contador menor pero valido estructuralmente. | Reintroduccion de versiones vulnerables. |
| TM-T6 | Env var poisoning | Forzar `OCLW_CRYPTO_PLUGIN`/symbol a ruta no confiable en ejecucion. | Seleccion de backend no aprobado. |
| TM-T7 | TOCTOU (verify-then-replace) | Cambiar archivo entre lectura/verificacion y uso posterior. | Bypass parcial de verificaciones. |

## 3. Controles existentes y evidencia (trazabilidad)

| Threat ID | Control implementado | Gate/evidencia |
| --- | --- | --- |
| TM-T1 | Parser estricto, limites y casos negativos de formato; comparaciones robustas en validacion. | G16: `docs/VV/Execution_Logs/GATES/G16/rerun_01/G16_Report.md` (`smoke_rt_negative_cases`, `PACK_FORMAT_ERROR`). |
| TM-T2 | Verificacion de hash/tamano y caso negativo de binary tamper (fail-closed). | G16: `docs/VV/Execution_Logs/GATES/G16/rerun_01/G16_Report.md` (`case1_binary_tamper=PASS`). |
| TM-T4 | Trusted plugin loading con rechazo de plugin inseguro (`OCLW_PLUGIN_UNTRUSTED`). | G10: `docs/VV/Execution_Logs/GATES/G10/rerun_01/G10_Report.md` (`smoke_rt_untrusted_plugin=PASS`). |
| TM-T5 | Enforcement anti-rollback con backend de estado y deteccion de contador decreciente. | G18: `docs/VV/Execution_Logs/GATES/G18/rerun_01/G18_Report.md` (`smoke_rt_anti_rollback RESULT=PASS`). |
| TM-T6 | Validacion de strict policy con `poison env` (no degradacion observada). | G12: `docs/VV/Execution_Logs/GATES/G12/rerun_01/Acceptance_Report.md` (seccion `poison env`, PASS). |
| TM-T7 | Simulacion de staging read-only para evitar escrituras sobre pack en RT. | G12: `docs/VV/Execution_Logs/GATES/G12/rerun_01/Acceptance_Report.md` (criterio H, PASS). |

## 4. Gaps residuales y recomendaciones

| Gap ID | Gap observado | Riesgo | Recomendacion accionable |
| --- | --- | --- | --- |
| TM-G1 | **CLOSED**. Cobertura de path traversal/symlink cerrada por smoke dedicado en RT strict. | Riesgo mitigado en baseline actual (G31). | Evidencia: `docs/VV/Execution_Logs/GATES/G31/rerun_01/G31_Report.md` (`smoke_rt_pack_symlink_escape RESULT=PASS`). |
| TM-G2 | **CLOSED**. Cobertura TOCTOU cerrada con smokes deterministas de swap en manifest y binario. | Riesgo mitigado en baseline actual (G32). | Evidencia: `docs/VV/Execution_Logs/GATES/G32/rerun_01/G32_Report.md` (`smoke_rt_toctou_manifest_swap` y `smoke_rt_toctou_binary_swap` con `RESULT=PASS`). |
| TM-G3 | **CLOSED**. Politica de allowlist + permisos del plugin validada en RT strict. | Riesgo mitigado en baseline actual (G33). | Evidencia: `docs/VV/Execution_Logs/GATES/G33/rerun_01/G33_Report.md` (`smoke_rt_plugin_allowlist_policy RESULT=PASS`). |
| TM-G4 | Anti-rollback probado con backend DEV; falta evidencia en backend operacional endurecido. | Cobertura parcial de entorno real. | Definir backend de estado operacional (TPM/HSM/almacen seguro) y correr suite anti-rollback en target. |
| TM-G5 | `env var poisoning` cubierto en homelab (G12), pero falta prueba negativa focal de fallback ambient en todos los entrypoints RT. | Deriva de configuracion entre builds/entrypoints. | Agregar prueba de conformidad RT strict que fuerce env invalida en cada ruta de carga y exija comportamiento fail-closed/no-env. |

## 5. Pruebas negativas nuevas propuestas (sin implementar)

| Test ID | Nombre propuesto | Objetivo | Criterio PASS | Criterio FAIL |
| --- | --- | --- | --- | --- |
| OCLW-TST-3001 | `smoke_rt_pack_symlink_escape` | Detectar traversal/symlink attack en `OCLW_PACK_DIR` (manifest/bin apuntando fuera del directorio permitido). | Loader rechaza con error de formato/trust y no ejecuta kernel. `RESULT=PASS` si ambos intentos (manifest y bin symlink) fallan cerrado. | Cualquier carga/ejecucion exitosa de pack resuelto via symlink externo. |
| OCLW-TST-3002 | `smoke_rt_toctou_manifest_swap` | Simular TOCTOU reemplazando `manifest.kpack` entre verificacion y uso. | Carga aborta (mismatch/error) o usa snapshot consistente; nunca ejecuta con contenido cambiado. | El flujo finaliza `RESULT=PASS` operativo tras swap no detectado. |
| OCLW-TST-3003 | `smoke_rt_toctou_binary_swap` | Simular TOCTOU reemplazando `program.bin` durante el flujo de carga strict. | Deteccion de mismatch (hash/firma) y fail-closed sin ejecutar kernel. | Kernel ejecuta con binario intercambiado o sin error detectado. |
| OCLW-TST-3004 | `smoke_rt_plugin_symlink_substitution` | Verificar rechazo de plugin apuntado por symlink o ruta fuera de whitelist en strict RT. | `Configure_Plugin`/carga falla con estado de plugin no confiable y `RESULT=PASS` del test negativo. | Plugin se carga y verifica firma usando backend via symlink no autorizado. |
| OCLW-TST-3005 | `smoke_rt_rollback_persistence_rebootlike` | Validar persistencia anti-rollback entre ejecuciones (simulacion reinicio) con estado previo. | Primera carga con counter alto PASS; segunda carga con counter menor detecta rollback de forma determinista. | El contador decreciente se acepta o el estado se pierde entre ejecuciones. |

## 6. Priorizacion sugerida

1. `OCLW-TST-3001` (TM-G1) - P0  
2. `OCLW-TST-3002` (TM-G2) - P0  
3. `OCLW-TST-3003` (TM-G2) - P0  
4. `OCLW-TST-3004` (TM-G3) - P1  
5. `OCLW-TST-3005` (TM-G4) - P1

## 7. Referencias directas

- `docs/VV/Execution_Logs/GATES/G10/rerun_01/G10_Report.md`
- `docs/VV/Execution_Logs/GATES/G12/rerun_01/Acceptance_Report.md`
- `docs/VV/Execution_Logs/GATES/G16/rerun_01/G16_Report.md`
- `docs/VV/Execution_Logs/GATES/G18/rerun_01/G18_Report.md`
- `docs/VV/Execution_Logs/GATES/G31/rerun_01/G31_Report.md`
- `docs/VV/Execution_Logs/GATES/G32/rerun_01/G32_Report.md`
- `docs/VV/Execution_Logs/GATES/G33/rerun_01/G33_Report.md`
- `docs/VV/Execution_Logs/GATES/G30/rerun_02/G30_Audit_Report.md`

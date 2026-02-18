# G12 Homelab RT Acceptance Report

- UTC timestamp: 2026-02-18T21:47:17Z
- HEAD: 1d7acd3ad94d580249f0a9444940ddb706c2d858
- Bundle usado: dist/oclw_rt_bundle_20260218T214717Z.tar.gz
- TARGET: /tmp/oclw_g12_target_20260218T214717Z
- POCL_CACHE_DIR: /tmp/oclw_pocl_cache_20260218T214717Z
- Plugin path (staging): /tmp/oclw_g12_target_20260218T214717Z/lib/liboclw_crypto_provider_ref.so

## Plugin Trust/Perms
- Evidencia: `docs/VV/Execution_Logs/GATES/G12/rerun_01/09_plugin_perms.log`

## Matriz A..H

| Criterio | Comando | Exit code | RESULT=PASS | Estado |
| --- | --- | ---: | --- | --- |
| A Build | `gprbuild -P tests/tests.gpr -p` | 0 | n/a | PASS |
| B Bundle | `tools/package_rt_bundle.sh` | 0 | n/a | PASS |
| C Offline pack unsigned | `env -i ... ./tests/bin/gen_pack_add1` | 0 | RESULT=PASS | PASS |
| D RT load unsigned no-JIT | `env -i ... ./tests/bin/smoke_rt_load_pack_add1` | 0 | RESULT=PASS | PASS |
| E Firma via plugin ref | `env -i ... ./tests/bin/smoke_rt_signature_plugin` | 0 | RESULT=PASS | PASS |
| F RT strict policy | `env -i ... ./tests/bin/smoke_rt_strict_policy` | 0 | RESULT=PASS | PASS |
| G Trusted hardening | `env -i ... ./tests/bin/smoke_rt_untrusted_plugin` | 0 | RESULT=PASS | PASS |
| H RO simulation | `chmod -R a-w TARGET; env -i ... smoke_rt_load_pack_add1` | 0 | RESULT=PASS | PASS |

## Check estricto adicional (poison env)
- Comando: `env -i OCLW_CRYPTO_PLUGIN=/nonexistent/invalid.so ... ./tests/bin/smoke_rt_strict_policy`
- Exit code: 0
- RESULT: RESULT=PASS
- Estado: PASS

## Extractos clave
- Ver: `docs/VV/Execution_Logs/GATES/G12/rerun_01/17_key_extracts.log`

```text
## 10_gen_pack_unsigned
6:RESULT=PASS

## 11_rt_load_unsigned
4:INFO negative_fingerprint_check=PASS
5:RESULT=PASS

## 12_rt_signature_plugin
4:INFO verifier_mode=REFERENCE_PLUGIN (NOT CRYPTO)
9:INFO positive_case=PASS
10:INFO negative_case=PASS expected=OCLW_SIGNATURE_INVALID
11:RESULT=PASS

## 13_rt_strict_policy_normal
4:INFO strict_policy_mode=ENABLED
5:INFO verifier_mode=REFERENCE_PLUGIN (NOT CRYPTO)
8:INFO case1=PASS expected=OCLW_SIGNATURE_MISSING
9:INFO case2=PASS expected=OCLW_SIGNATURE_DISALLOWED|OCLW_SIGNATURE_INVALID
10:INFO case3=PASS
11:RESULT=PASS

## 14_rt_strict_policy_poison_env
4:INFO strict_policy_mode=ENABLED
5:INFO verifier_mode=REFERENCE_PLUGIN (NOT CRYPTO)
8:INFO case1=PASS expected=OCLW_SIGNATURE_MISSING
9:INFO case2=PASS expected=OCLW_SIGNATURE_DISALLOWED|OCLW_SIGNATURE_INVALID
10:INFO case3=PASS
11:RESULT=PASS

## 15_rt_untrusted_plugin
2:INFO strict_policy_mode=ENABLED
3:INFO verifier_mode=REFERENCE_PLUGIN (NOT CRYPTO)
7:INFO configure_plugin_status=OCLW_PLUGIN_UNTRUSTED status_int=-32020
8:RESULT=PASS

## 16_rt_load_ro_sim
4:INFO negative_fingerprint_check=PASS
5:RESULT=PASS
```

## Bundle evidence
- Build log: `docs/VV/Execution_Logs/GATES/G12/rerun_01/04_bundle_build.log`
- Lista tar (top 80): `docs/VV/Execution_Logs/GATES/G12/rerun_01/05_bundle_list.log`

## Conclusión
- Resultado final G12: PASS

- Todos los criterios A..H y check de poison env cumplen en homelab.

## Reproducción manual (principal)
```bash
cd /home/tangodelta/opencl-ada-wrapper
REPORT_DIR=docs/VV/Execution_Logs/GATES/G12/rerun_01
mkdir -p "$REPORT_DIR"
gprbuild -P tests/tests.gpr -p
tools/package_rt_bundle.sh
# usar el bundle más nuevo en dist/ para staging en /tmp
# ejecutar: gen_pack_add1, smoke_rt_load_pack_add1, smoke_rt_signature_plugin,
# smoke_rt_strict_policy (normal+poison env), smoke_rt_untrusted_plugin,
# y rt_load en staging read-only con OCLW_PACK_DIR y POCL_CACHE_DIR externos.
```

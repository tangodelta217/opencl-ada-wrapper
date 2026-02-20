# EW MLP Demo (Quantized, Deterministic)

## Objetivo
Demostrar un pipeline de inferencia MLP cuantizado en OpenCL+Ada con foco en:
- Correctitud bit-exact CPU vs OpenCL.
- Ejecucion RT no-JIT mediante Kernel Pack (manifest + program.bin).
- Metricas de performance operativas (`p50`/`p99`) para latencia y throughput.

## Alcance Tecnico (MLP-100)
- Topologia: `Input=64`, `Hidden=96`, `Output=4`.
- Activacion: ReLU.
- Aritmetica: enteros unicamente (`int-only`).
- Salida: clasificacion de 4 clases.

## Dataset Sintetico (No Sensible)
- Dataset sintetico determinista, sin datos operacionales reales.
- Estructura: 4 clases por banda con patrones numericos estables.
- Razon de representatividad:
  - Permite validar separacion de clases por caracteristicas de banda.
  - Permite pruebas repetibles para regresion y comparacion bit-exact.
  - Evita uso de informacion sensible de mision.

## Que Se Demuestra
1. Correctitud funcional:
   - Misma entrada produce misma salida en CPU y OpenCL (comparacion exacta).
2. Ruta RT:
   - Carga desde binario (`Create_From_Binary`) en lugar de compilacion JIT.
3. Rendimiento basico:
   - Latencia y throughput reportados con percentiles `p50`/`p99`.

## Como Ejecutar
Comando unico (entrypoint demo):

```bash
tools/run_demo_ew_mlp.sh
```

Comandos base (alternativa):

```bash
gprbuild -P tests/tests.gpr
tools/run_smoke.sh
```

Ejecucion directa del demo:

```bash
./tests/bin/demo_ew_mlp
```

Flujo RT no-JIT:
- Generar pack offline (`manifest.kpack` + `program.bin`).
- Cargar pack en ruta RT.
- Ejecutar inferencia sin fallback a source.

## Ejemplo de Output
Salida esperada (formato estable):

```text
INFO demo=ew_mlp
INFO mlp_shape=in64_hidden96_out4
INFO quant=int_only_u8_i8_i32
INFO batch=1024
INFO fingerprint_name=pthread-haswell-Intel(R) Core(TM) i7-8650U CPU @ 1.90GHz
INFO fingerprint_vendor=GenuineIntel
INFO fingerprint_driver=3.1+debian
INFO fingerprint_version=OpenCL 3.0 PoCL
INFO rt_pack_generation=PASS
INFO mode=RT_NOJIT
INFO strict_signature=ATTEMPTED
INFO latency_host_ns=...
INFO throughput_vectors_per_sec=...
INFO accuracy=1024/1024
INFO confusion_row_0=256,0,0,0
INFO confusion_row_1=0,256,0,0
INFO confusion_row_2=0,0,256,0
INFO confusion_row_3=0,0,0,256
INFO visual_class_0 sum_band0=... sum_band1=... sum_band2=... sum_band3=... predicted=0 expected=0
INFO visual_class_1 sum_band0=... sum_band1=... sum_band2=... sum_band3=... predicted=1 expected=1
INFO visual_class_2 sum_band0=... sum_band1=... sum_band2=... sum_band3=... predicted=2 expected=2
INFO visual_class_3 sum_band0=... sum_band1=... sum_band2=... sum_band3=... predicted=3 expected=3
RESULT=PASS
```

## Output Esperado (Defense-Friendly)
- Lineas estables y parseables:
  - `RESULT=PASS|FAIL|SKIP`
  - `INFO ...` acotado
- Sin logs verbosos por defecto.

## No Claims
- Esta demo no es un modelo entrenado operacional real.
- No reclama performance representativa fuera del target HW final.
- Es un demostrador de pipeline (correctitud, trazabilidad y ruta RT no-JIT).

## Trazabilidad Objetivo
- Requisitos: `OCLW-REQ-0401..0404`.
- Tests planeados: `OCLW-TST-0401..0403`.
- Evidencia planeada: reporte de gate de demo en `docs/VV/Execution_Logs/GATES/`.

# G4 Verification Report (verify_01)

- Timestamp UTC: 2026-02-18T01:51:12Z
- HEAD: c7c51a498487b6d1592f4079bafe8e06cff410b2
- Gate: G4 (Program Binaries / no-JIT path preliminar)
- Overall result: **PASS**

## Checklist A-E

| Item | Resultado | Evidencia breve |
| --- | --- | --- |
| A1. SDD contiene Program binaries/no-JIT | PASS | docs/ARCH/SDD.md (match por texto) |
| A2. Existe ADR-0007 | PASS | docs/ARCH/ADR-0007-program-binaries-nojit-rt-path.md |
| B1. Raw define CL_PROGRAM_BINARY_SIZES/CL_PROGRAM_BINARIES | PASS | src/opencl/raw/opencl-raw-api.ads |
| B2. Raw importa clCreateProgramWithBinary | PASS | src/opencl/raw/opencl-raw-api.ads |
| B3. clGetProgramInfo disponible | PASS | src/opencl/raw/opencl-raw-api.ads |
| C1. API thick expone Binary_Size/Get_Binary/Create_From_Binary (.ads) | PASS | src/opencl/core/opencl-core-programs.ads |
| C2. Implementación thick presente (.adb) | PASS | src/opencl/core/opencl-core-programs.adb |
| D1. Existe smoke_program_binary_roundtrip | PASS | tests/smoke/smoke_program_binary_roundtrip.adb |
| D2. tests.gpr incluye smoke_program_binary_roundtrip | PASS | tests/tests.gpr |
| D3. run_smoke ejecuta/considera binary_roundtrip y POCL_CACHE_DIR | PASS | tools/run_smoke.sh |
| E1. Build tests OK (gprbuild) | PASS | 03_build.log exit=0 |
| E2. Harness OK (tools/run_smoke.sh) | PASS | 04_run_smoke.log exit=0 |
| E3. binary_roundtrip reporta RESULT=PASS + binary_size + checksum | PASS | 04_run_smoke.log |
| E4. smoke_kernel_add1 sanity OK | PASS | 04_run_smoke.log |

## Evidencias (snippets)

### 01_repo.log
```text
timestamp_utc=2026-02-18T01:51:12Z
head_sha=c7c51a498487b6d1592f4079bafe8e06cff410b2
git_status_short_begin
 M docs/ARCH/SDD.md
 M src/opencl/core/opencl-core-programs.adb
 M src/opencl/core/opencl-core-programs.ads
 M src/opencl/raw/opencl-raw-api.ads
 M tests/tests.gpr
 M tools/run_smoke.sh
?? docs/ARCH/ADR-0007-program-binaries-nojit-rt-path.md
?? docs/VV/Execution_Logs/GATES/G4/
?? tests/smoke/smoke_program_binary_roundtrip.adb
git_status_short_end
uname=Linux tangodelta 6.14.0-37-generic #37~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Thu Nov 20 10:25:38 UTC 2 x86_64 x86_64 x86_64 GNU/Linux
```

### 02_checks.log
```text
3:PASS exists: docs/ARCH/SDD.md
4:PASS exists: docs/ARCH/ADR-0007-program-binaries-nojit-rt-path.md
8:PASS exists: tests/smoke/smoke_program_binary_roundtrip.adb
13:$ rg -n -i program binaries|no-jit docs/ARCH/SDD.md
20:$ rg -n -i binaries|no-jit docs/ARCH/ADR-0007-program-binaries-nojit-rt-path.md
28:$ rg -n CL_PROGRAM_BINARY_SIZES|CL_PROGRAM_BINARIES|clCreateProgramWithBinary|clGetProgramInfo src/opencl/raw/opencl-raw-api.ads
29:164:   CL_PROGRAM_BINARY_SIZES : constant cl_program_info := 16#1165#;
30:165:   CL_PROGRAM_BINARIES : constant cl_program_info := 16#1166#;
31:322:   function clCreateProgramWithBinary
32:333:     External_Name => "clCreateProgramWithBinary";
33:347:   function clGetProgramInfo
34:356:     External_Name => "clGetProgramInfo";
38:$ rg -n Binary_Size|Get_Binary|Create_From_Binary src/opencl/core/opencl-core-programs.ads src/opencl/core/opencl-core-programs.adb
39:src/opencl/core/opencl-core-programs.ads:38:   procedure Binary_Size
40:src/opencl/core/opencl-core-programs.ads:43:   procedure Get_Binary
41:src/opencl/core/opencl-core-programs.ads:49:   procedure Create_From_Binary
42:src/opencl/core/opencl-core-programs.adb:309:   procedure Binary_Size
43:src/opencl/core/opencl-core-programs.adb:344:   end Binary_Size;
44:src/opencl/core/opencl-core-programs.adb:346:   procedure Get_Binary
45:src/opencl/core/opencl-core-programs.adb:369:      Binary_Size
46:src/opencl/core/opencl-core-programs.adb:401:   end Get_Binary;
47:src/opencl/core/opencl-core-programs.adb:403:   procedure Create_From_Binary
48:src/opencl/core/opencl-core-programs.adb:477:   end Create_From_Binary;
52:$ rg -n smoke_program_binary_roundtrip(\.adb)? tests/tests.gpr
53:14:      "smoke_program_binary_roundtrip.adb");
57:$ rg -n smoke_program_binary_roundtrip|POCL_CACHE_DIR tools/run_smoke.sh
58:17:if [ -z "${POCL_CACHE_DIR:-}" ]; then
59:18:  export POCL_CACHE_DIR="${REPO_ROOT}/.pocl_kcache"
60:19:  mkdir -p "${POCL_CACHE_DIR}"
61:46:  echo "pocl_cache_dir=${POCL_CACHE_DIR:-<unset>}"
62:55:SMOKE_PROGRAM_BINARY_ROUNDTRIP_EXEC="$(find_smoke_executable "smoke_program_binary_roundtrip")"
63:92:    echo "ERROR missing smoke executable: smoke_program_binary_roundtrip"
64:109:  echo "smoke_program_binary_roundtrip_executable=${SMOKE_PROGRAM_BINARY_ROUNDTRIP_EXEC}"
65:130:run_and_log_smoke "smoke_program_binary_roundtrip" "${SMOKE_PROGRAM_BINARY_ROUNDTRIP_EXEC}" || OVERALL_RC=$?
```

### 03_build.log
```text
gprbuild: "smoke_platforms" up to date
gprbuild: "smoke_core" up to date
gprbuild: "smoke_buffer_roundtrip" up to date
gprbuild: "smoke_kernel_add1" up to date
gprbuild: "smoke_program_binary_roundtrip" up to date
gprbuild_exit_code=0
```

### 04_run_smoke.log
```text
52:gprbuild: "smoke_kernel_add1" up to date
53:gprbuild: "smoke_program_binary_roundtrip" up to date
66:smoke_kernel_add1_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_kernel_add1
67:smoke_program_binary_roundtrip_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_program_binary_roundtrip
100:RESULT=PASS
102:$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_kernel_add1
104:RESULT=PASS
105:smoke_kernel_add1_exit_code=0
106:$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_program_binary_roundtrip
107:INFO binary_size=48617
108:INFO binary_fnv1a32=34932304
109:RESULT=PASS
110:smoke_program_binary_roundtrip_exit_code=0
111:smoke_exit_code=0
114:run_smoke_exit_code=0
```

### 05_run_binary_roundtrip.log
```text
lookup_binary=./tests/bin/smoke_program_binary_roundtrip
binary_found=1
$ ./tests/bin/smoke_program_binary_roundtrip
INFO binary_size=48593
INFO binary_fnv1a32=59974699
RESULT=PASS
binary_exit_code=0
```

## FAIL items

No se detectaron ítems en FAIL en esta corrida de verificación.

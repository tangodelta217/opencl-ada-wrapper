# Gate G7 Rerun 01 Report

- UTC timestamp: 2026-02-18T17:22:35Z
- git HEAD: dcad884aa1a0a458c70fefe1072d5031443c77ff

## Build
- Command:   `gprbuild -P tests/tests.gpr`
- stdout+stderr log:   `docs/VV/Execution_Logs/GATES/G7/rerun_01/01_build.log`

### Build Output (snippet)
```text
gprbuild: "smoke_platforms" up to date
gprbuild: "smoke_core" up to date
gprbuild: "gen_pack_add1" up to date
gprbuild: "smoke_rt_load_pack_add1" up to date
gprbuild: "smoke_rt_negative_cases" up to date
gprbuild: "smoke_rt_signature_enforcement" up to date
gprbuild: "smoke_buffer_roundtrip" up to date
gprbuild: "smoke_kernel_add1" up to date
gprbuild: "smoke_program_binary_roundtrip" up to date
``` 

## Run
- Command: 
  `tools/run_smoke.sh`
- stdout+stderr log: 
  `docs/VV/Execution_Logs/GATES/G7/rerun_01/02_run_smoke.log`

### Run Output (snippet)
```text
=== Build Start ===
timestamp_utc=20260218T172235Z
repo_root=/home/tangodelta/opencl-ada-wrapper
uname=Linux tangodelta 6.14.0-37-generic #37~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Thu Nov 20 10:25:38 UTC 2 x86_64 x86_64 x86_64 GNU/Linux
$ gprbuild --version
GPRBUILD Pro 18.0w (19940713) (x86_64-linux-gnu)
Copyright (C) 2004-2016, AdaCore
This is free software; see the source for copying conditions.
See your AdaCore support agreement for details of warranty and support.
If you do not have a current support agreement, then there is absolutely
no warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR
PURPOSE.

$ gnatls -v

GNATLS 13.3.0
Copyright (C) 1997-2023, Free Software Foundation, Inc.

Source Search Path:
   <Current_Directory>
   /usr/lib/gcc/x86_64-linux-gnu/13/adainclude


Object Search Path:
   <Current_Directory>
   /usr/lib/gcc/x86_64-linux-gnu/13/adalib


Project Search Path:
   <Current_Directory>
   /usr/x86_64-linux-gnu/lib/gnat
   /usr/x86_64-linux-gnu/share/gpr
   /usr/share/gpr
   /usr/lib/gnat

$ gcc -v
Using built-in specs.
COLLECT_GCC=gcc
COLLECT_LTO_WRAPPER=/usr/libexec/gcc/x86_64-linux-gnu/13/lto-wrapper
OFFLOAD_TARGET_NAMES=nvptx-none:amdgcn-amdhsa
OFFLOAD_TARGET_DEFAULT=1
Target: x86_64-linux-gnu
Configured with: ../src/configure -v --with-pkgversion='Ubuntu 13.3.0-6ubuntu2~24.04' --with-bugurl=file:///usr/share/doc/gcc-13/README.Bugs --enable-languages=c,ada,c++,go,d,fortran,objc,obj-c++,m2 --prefix=/usr --with-gcc-major-version-only --program-suffix=-13 --program-prefix=x86_64-linux-gnu- --enable-shared --enable-linker-build-id --libexecdir=/usr/libexec --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --enable-bootstrap --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-libstdcxx-backtrace --enable-gnu-unique-object --disable-vtable-verify --enable-plugin --enable-default-pie --with-system-zlib --enable-libphobos-checking=release --with-target-system-zlib=auto --enable-objc-gc=auto --enable-multiarch --disable-werror --enable-cet --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64,mx32 --enable-multilib --with-tune=generic --enable-offload-targets=nvptx-none=/build/gcc-13-fG75Ri/gcc-13-13.3.0/debian/tmp-nvptx/usr,amdgcn-amdhsa=/build/gcc-13-fG75Ri/gcc-13-13.3.0/debian/tmp-gcn/usr --enable-offload-defaulted --without-cuda-driver --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu --with-build-config=bootstrap-lto-lean --enable-link-serialization=2
Thread model: posix
Supported LTO compression algorithms: zlib zstd
gcc version 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04) 
$ gprbuild -P opencl_wrapper.gpr -p
$ gprbuild -P tests/tests.gpr -p
gprbuild: "smoke_platforms" up to date
gprbuild: "smoke_core" up to date
gprbuild: "gen_pack_add1" up to date
gprbuild: "smoke_rt_load_pack_add1" up to date
gprbuild: "smoke_rt_negative_cases" up to date
gprbuild: "smoke_rt_signature_enforcement" up to date
gprbuild: "smoke_buffer_roundtrip" up to date
gprbuild: "smoke_kernel_add1" up to date
gprbuild: "smoke_program_binary_roundtrip" up to date
smoke_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_platforms
build_log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172235Z_build.log
=== Build End ===
=== Smoke Run Start ===
timestamp_utc=20260218T172236Z
repo_root=/home/tangodelta/opencl-ada-wrapper
pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1
oclw_pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1
pocl_cache_dir=/home/tangodelta/opencl-ada-wrapper/.pocl_kcache
pocl_kernel_cache=0
pocl_cache_configured_by_harness=1
smoke_platforms_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_platforms
smoke_core_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_core
gen_pack_add1_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/gen_pack_add1
smoke_rt_load_pack_add1_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_load_pack_add1
smoke_rt_negative_cases_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_negative_cases
smoke_rt_signature_enforcement_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_signature_enforcement
smoke_buffer_roundtrip_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_buffer_roundtrip
smoke_kernel_add1_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_kernel_add1
smoke_program_binary_roundtrip_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_program_binary_roundtrip
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_platforms
platform_count_reported= 1
platform_count_used= 1
Platform[ 0]
  name    : Portable Computing Language
  vendor  : The pocl project
  version : OpenCL 3.0 PoCL 5.0+debian  Linux, None+Asserts, RELOC, SPIR, LLVM 16.0.6, SLEEF, DISTRO, POCL_DEBUG
  device_count_reported= 1
  device_count_used= 1
  Device[ 0]
    name    : cpu-haswell-Intel(R) Core(TM) i5-14600K
    vendor  : GenuineIntel
    driver  : 5.0+debian
    version : OpenCL 3.0 PoCL HSTR: cpu-x86_64-pc-linux-gnu-haswell
    type    : 2
smoke_platforms_exit_code=0
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_core
platform_capacity= 16
platform_count_used= 1
Platform[ 0]
  name    : Portable Computing Language
  vendor  : The pocl project
  version : OpenCL 3.0 PoCL 5.0+debian  Linux, None+Asserts, RELOC, SPIR, LLVM 16.0.6, SLEEF, DISTRO, POCL_DEBUG
  device_capacity= 64
  device_count_used= 1
  Device[ 0]
    name    : cpu-haswell-Intel(R) Core(TM) i5-14600K
    vendor  : GenuineIntel
    version : OpenCL 3.0 PoCL HSTR: cpu-x86_64-pc-linux-gnu-haswell
    driver  : 5.0+debian
smoke_core_exit_code=0
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/gen_pack_add1
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1
INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/manifest.kpack
INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/program.bin
INFO binary_size=48617
INFO binary_fnv1a32=2576152867
RESULT=PASS
gen_pack_add1_exit_code=0
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_load_pack_add1
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1
INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/manifest.kpack
INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/program.bin
INFO negative_fingerprint_check=PASS
RESULT=PASS
smoke_rt_load_pack_add1_exit_code=0
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_negative_cases
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1
INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/manifest.kpack
INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/program.bin
INFO case1_binary_tamper=PASS expected=OCLW_HASH_MISMATCH
INFO case2_fingerprint_tamper=PASS expected=OCLW_FINGERPRINT_MISMATCH
INFO case3_format_tamper=PASS expected=OCLW_PACK_FORMAT_ERROR
RESULT=PASS
smoke_rt_negative_cases_exit_code=0
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_signature_enforcement
INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1
INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/manifest.kpack
INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/program.bin
INFO verifier_mode=TEST-FNV1A32 (NOT CRYPTO)
INFO gen_pack_add1_return_code=0 log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/gen_pack_add1.log
INFO caseA=PASS expected=OCLW_SIGNATURE_NOT_IMPLEMENTED
INFO caseB=PASS
RESULT=PASS
smoke_rt_signature_enforcement_exit_code=0
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_buffer_roundtrip
RESULT=PASS
smoke_buffer_roundtrip_exit_code=0
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_kernel_add1
INFO device_opencl_c_version=OpenCL C 1.2 PoCL
RESULT=PASS
smoke_kernel_add1_exit_code=0
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_program_binary_roundtrip
INFO binary_size=48617
INFO binary_fnv1a32=2114071279
RESULT=PASS
smoke_program_binary_roundtrip_exit_code=0
gen_pack_add1_exit_code=0
smoke_rt_load_pack_add1_exit_code=0
smoke_rt_negative_cases_exit_code=0
smoke_rt_signature_enforcement_exit_code=0
pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1
smoke_exit_code=0
smoke_log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_smoke_run.log
=== Smoke Run End ===
```

## Extracts Requested
- Source log: `docs/VV/Execution_Logs/GATES/G7/rerun_01/03_extracts.log`

### RESULT de `smoke_rt_signature_enforcement`
- `RESULT=PASS`
- `smoke_rt_signature_enforcement_exit_code=0`

### `caseA` / `caseB` (si aparecen)
- `INFO caseA=PASS expected=OCLW_SIGNATURE_NOT_IMPLEMENTED`
- `INFO caseB=PASS`

### Extracts (exact lines)
```text
# G7 extracts from run_smoke

## smoke_rt_signature_enforcement lines
54:gprbuild: "smoke_rt_signature_enforcement" up to date
74:smoke_rt_signature_enforcement_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_signature_enforcement
115:RESULT=PASS
122:RESULT=PASS
131:RESULT=PASS
133:$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_signature_enforcement
139:INFO caseA=PASS expected=OCLW_SIGNATURE_NOT_IMPLEMENTED
140:INFO caseB=PASS
141:RESULT=PASS
142:smoke_rt_signature_enforcement_exit_code=0
144:RESULT=PASS
148:RESULT=PASS
153:RESULT=PASS
158:smoke_rt_signature_enforcement_exit_code=0

## explicit RESULT for smoke_rt_signature_enforcement
133:$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_rt_signature_enforcement
134:INFO pack_dir=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1
135:INFO manifest_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/manifest.kpack
136:INFO binary_path=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/program.bin
137:INFO verifier_mode=TEST-FNV1A32 (NOT CRYPTO)
138:INFO gen_pack_add1_return_code=0 log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T172236Z_kpack_add1/gen_pack_add1.log
139:INFO caseA=PASS expected=OCLW_SIGNATURE_NOT_IMPLEMENTED
140:INFO caseB=PASS
141:RESULT=PASS
142:smoke_rt_signature_enforcement_exit_code=0
```

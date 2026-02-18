# G4 Report (rerun_02)

- UTC timestamp: 2026-02-18T02:01:53Z
- HEAD: 776cb97208dc5054559e8251c831989aef759c63

## Build

- Command: `gprbuild -P tests/tests.gpr`
- Exit code: 0

```text
gprbuild: "smoke_platforms" up to date
gprbuild: "smoke_core" up to date
gprbuild: "smoke_buffer_roundtrip" up to date
gprbuild: "smoke_kernel_add1" up to date
gprbuild: "smoke_program_binary_roundtrip" up to date
```

## Run

- Command: `tools/run_smoke.sh`
- Exit code: 0

```text
=== Build Start ===
timestamp_utc=20260218T020153Z
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
gprbuild: "smoke_buffer_roundtrip" up to date
gprbuild: "smoke_kernel_add1" up to date
gprbuild: "smoke_program_binary_roundtrip" up to date
smoke_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_platforms
build_log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T020153Z_build.log
=== Build End ===
=== Smoke Run Start ===
timestamp_utc=20260218T020154Z
repo_root=/home/tangodelta/opencl-ada-wrapper
pocl_cache_dir=/home/tangodelta/opencl-ada-wrapper/.pocl_kcache
pocl_kernel_cache=0
pocl_cache_configured_by_harness=1
smoke_platforms_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_platforms
smoke_core_executable=/home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_core
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
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_buffer_roundtrip
RESULT=PASS
smoke_buffer_roundtrip_exit_code=0
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_kernel_add1
INFO device_opencl_c_version=OpenCL C 1.2 PoCL
RESULT=PASS
smoke_kernel_add1_exit_code=0
$ /home/tangodelta/opencl-ada-wrapper/tests/bin/smoke_program_binary_roundtrip
INFO binary_size=48617
INFO binary_fnv1a32=3402838843
RESULT=PASS
smoke_program_binary_roundtrip_exit_code=0
smoke_exit_code=0
smoke_log=/home/tangodelta/opencl-ada-wrapper/docs/VV/Execution_Logs/local/20260218T020154Z_smoke_run.log
=== Smoke Run End ===
```

## Extracted

- smoke_program_binary_roundtrip RESULT: RESULT=PASS
- smoke_program_binary_roundtrip binary_size: INFO binary_size=48617
- smoke_program_binary_roundtrip fnv1a32: INFO binary_fnv1a32=3402838843
- POCL_CACHE_DIR usado: pocl_cache_dir=/home/tangodelta/opencl-ada-wrapper/.pocl_kcache

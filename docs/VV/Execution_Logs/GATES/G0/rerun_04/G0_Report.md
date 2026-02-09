# Gate G0 Report (Rerun 04)

- UTC timestamp: 2026-02-09T17:05:35Z
- Commit (HEAD): 24864a334f03a701370a3694463f5c59a7a0782b

## 1) Repository Layout

```text
$ ls -R
.:
AGENTS.md
README.md
docs
obj
opencl_wrapper.gpr
src
tests
tools

./docs:
ADR
ARCH
CM
PM
REQ
VV

./docs/ADR:
OCLW-ADR-0002-build-skeleton-gprbuild.md
OCLW-ADR-0003-thin-ffi-platform-device-enumeration.md

./docs/ARCH:
ADR-0001-baseline-opencl-1.2.md
ADR-0002-ffi-abi-mapping.md
ADR-0003-opaque-handle-mapping.md
SDD.md

./docs/CM:
SCMP.md

./docs/PM:
Risk_Register.md

./docs/REQ:
SRS.md

./docs/VV:
Execution_Logs
SVVP.md
Smoke_Test_Design.md

./docs/VV/Execution_Logs:
2026-02-09_OCLW-TST-0001_smoke.md
2026-02-09_OCLW-TST-0002_smoke_platforms.md
2026-02-09_build_smoke.log
2026-02-09_build_smoke_after_devops.log
2026-02-09_ffi_smoke_build.log
GATES
README.md
local

./docs/VV/Execution_Logs/GATES:
G0

./docs/VV/Execution_Logs/GATES/G0:
01_repo_layout.log
02_gprbuild_version.log
03_gcc_version.log
04_gnatls_version.log
05_build_tests.log
06_smoke_run.log
G0_Report.md
rerun_01
rerun_02
rerun_03
rerun_04

./docs/VV/Execution_Logs/GATES/G0/rerun_01:
01_repo_layout.log
02_toolchain.log
03_build.log
04_smoke.log
G0_Report.md

./docs/VV/Execution_Logs/GATES/G0/rerun_02:
01_repo_layout.log
02_toolchain.log
03_build.log
04_smoke.log
G0_Report.md

./docs/VV/Execution_Logs/GATES/G0/rerun_03:
01_repo_layout.log
02_toolchain.log
03_build.log
04_smoke.log
G0_Report.md

./docs/VV/Execution_Logs/GATES/G0/rerun_04:
01_repo_layout.log

./docs/VV/Execution_Logs/local:
20260209T034752Z_build.log
20260209T034755Z_build.log
20260209T034805Z_build.log

./obj:
opencl-raw-api.ads.stderr
opencl-raw-api.ads.stdout
opencl-raw-api.ali
opencl-raw-api.o
opencl-raw.ads.stderr
opencl-raw.ads.stdout
opencl-raw.ali
opencl-raw.o
opencl.adb.stderr
opencl.adb.stdout
opencl.ads.stderr
opencl.ads.stdout
opencl.ali
opencl.o

./src:
opencl

./src/opencl:
opencl.ads
raw

./src/opencl/raw:
opencl-raw-api.ads
opencl-raw.ads

./tests:
bin
obj
oclw_tst_0001_smoke.adb
smoke
tests.gpr

./tests/bin:
smoke_platforms

./tests/obj:
b__smoke_platforms.adb
b__smoke_platforms.ads
b__smoke_platforms.ali
b__smoke_platforms.o
smoke_platforms.adb.stderr
smoke_platforms.adb.stdout
smoke_platforms.ali
smoke_platforms.bexch
smoke_platforms.o

./tests/smoke:
smoke_platforms.adb

./tools:
build.sh
run_smoke.sh
```

## 2) Toolchain

```text
$ gprbuild --version
GPRBUILD Pro 18.0w (19940713) (x86_64-linux-gnu)
Copyright (C) 2004-2016, AdaCore
This is free software; see the source for copying conditions.
See your AdaCore support agreement for details of warranty and support.
If you do not have a current support agreement, then there is absolutely
no warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR
PURPOSE.


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

```

## 3) Build

```text
$ gprbuild -P tests/tests.gpr -v -f
Changing to object directory of "Tests": "/home/tangodelta/opencl-ada-wrapper/tests/obj/"
/usr/bin/gcc-13 -c -x ada -gnatA -gnatec=/tmp/GPR.140859/GNAT-TEMP-000003.TMP -gnatem=/tmp/GPR.140859/GNAT-TEMP-000004.TMP /home/tangodelta/opencl-ada-wrapper/tests/smoke/smoke_platforms.adb
Changing to object directory of "OpenCL_Wrapper": "/home/tangodelta/opencl-ada-wrapper/obj/"
/usr/bin/gcc-13 -c -x ada -gnatA -gnatec=/tmp/GPR.140859/GNAT-TEMP-000005.TMP -gnatem=/tmp/GPR.140859/GNAT-TEMP-000006.TMP /home/tangodelta/opencl-ada-wrapper/src/opencl/opencl.ads
/usr/bin/gcc-13 -c -x ada -gnatA -gnatec=/tmp/GPR.140859/GNAT-TEMP-000005.TMP -gnatem=/tmp/GPR.140859/GNAT-TEMP-000006.TMP /home/tangodelta/opencl-ada-wrapper/src/opencl/raw/opencl-raw.ads
/usr/bin/gcc-13 -c -x ada -gnatA -gnatec=/tmp/GPR.140859/GNAT-TEMP-000005.TMP -gnatem=/tmp/GPR.140859/GNAT-TEMP-000006.TMP /home/tangodelta/opencl-ada-wrapper/src/opencl/raw/opencl-raw-api.ads
Changing to object directory of "Tests": "/home/tangodelta/opencl-ada-wrapper/tests/obj/"
/usr/libexec/gprbuild/gprbind smoke_platforms.bexch
/usr/bin/gnatbind -o b__smoke_platforms.adb /home/tangodelta/opencl-ada-wrapper/tests/obj/smoke_platforms.ali -x -F=/tmp/GPR.140859/GNAT-TEMP-000007.TMP -O=/tmp/GPR.140880/GNAT-TEMP-000001.TMP
/usr/bin/gcc-13 -c -x ada -gnatA -c -gnatA -gnatWb -gnatiw -gnatws -mtune=generic -march=x86-64 b__smoke_platforms.adb -o b__smoke_platforms.o
/usr/bin/gcc-13 smoke_platforms.o b__smoke_platforms.o /home/tangodelta/opencl-ada-wrapper/obj/opencl.o /home/tangodelta/opencl-ada-wrapper/obj/opencl-raw.o /home/tangodelta/opencl-ada-wrapper/obj/opencl-raw-api.o -lOpenCL -L/home/tangodelta/opencl-ada-wrapper/tests/obj/ -L/home/tangodelta/opencl-ada-wrapper/tests/obj/ -L/home/tangodelta/opencl-ada-wrapper/obj/ -L/usr/lib/gcc/x86_64-linux-gnu/13/adalib/ -shared-libgcc -lgnat-13 -ldl -Wl,-rpath-link,/usr/lib/gcc/x86_64-linux-gnu/13//adalib -Wl,-z,origin,-rpath,$ORIGIN/..//obj:$ORIGIN/../..//obj:/usr/lib/gcc/x86_64-linux-gnu/13/adalib -o /home/tangodelta/opencl-ada-wrapper/tests/bin//smoke_platforms
```

## 4) Smoke

```text
$ ./tests/bin/smoke_platforms
platform_count_reported= 0
platform_count_used= 0
INFO no platforms: CL_PLATFORM_NOT_FOUND_KHR
```

## 5) Link Evidence (OpenCL)

```text
$ grep -E "(-lOpenCL|libOpenCL)" 03_build.log
/usr/bin/gcc-13 smoke_platforms.o b__smoke_platforms.o /home/tangodelta/opencl-ada-wrapper/obj/opencl.o /home/tangodelta/opencl-ada-wrapper/obj/opencl-raw.o /home/tangodelta/opencl-ada-wrapper/obj/opencl-raw-api.o -lOpenCL -L/home/tangodelta/opencl-ada-wrapper/tests/obj/ -L/home/tangodelta/opencl-ada-wrapper/tests/obj/ -L/home/tangodelta/opencl-ada-wrapper/obj/ -L/usr/lib/gcc/x86_64-linux-gnu/13/adalib/ -shared-libgcc -lgnat-13 -ldl -Wl,-rpath-link,/usr/lib/gcc/x86_64-linux-gnu/13//adalib -Wl,-z,origin,-rpath,$ORIGIN/..//obj:$ORIGIN/../..//obj:/usr/lib/gcc/x86_64-linux-gnu/13/adalib -o /home/tangodelta/opencl-ada-wrapper/tests/bin//smoke_platforms
```

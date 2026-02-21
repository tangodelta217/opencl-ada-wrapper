# SBOM Full

- generated_utc=2026-02-20T00:07:16Z
- git_head=374d9a880c9d58ead4e3bcda4beb588ef3956dcd
- reproducible=1
- source_date_epoch=1771546036

## Toolchain Versions
```text
GPRBUILD Pro 18.0w (19940713) (x86_64-linux-gnu)
Copyright (C) 2004-2016, AdaCore
This is free software; see the source for copying conditions.


GNATLS 13.3.0
Copyright (C) 1997-2023, Free Software Foundation, Inc.

Source Search Path:
   <Current_Directory>
   /usr/lib/gcc/x86_64-linux-gnu/13/adainclude


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
```

## Runtime Libraries (OpenCL)
```text
	libOpenCL.so (libc6,x86-64) => /lib/x86_64-linux-gnu/libOpenCL.so
	libOpenCL.so.1 (libc6,x86-64) => /lib/x86_64-linux-gnu/libOpenCL.so.1
	libnvidia-opencl.so.1 (libc6,x86-64) => /lib/x86_64-linux-gnu/libnvidia-opencl.so.1
```

## Script Hashes (SHA-256)

| Path | SHA-256 |
|---|---|
| `tools/build.sh` | `6bdc0ad4ba3e8e319c902e005a33925bbe7ae297ff418ebaf754a073261e610b` |
| `tools/run_smoke.sh` | `d921a40e2f4c9a2d3e140056883c1db8c6800b56af0a8628749a35bab36f5da3` |
| `tools/package_rt_bundle.sh` | `c249d46cc05106e6c61bc99e8f8b6e83937174586b13df9ef4dbb2eb62a8d3bd` |
| `tools/gen_sbom_full.sh` | `ffb4580215d52aa7ec94d40dec29672ed7ae12c5b0fdf8d3da8eac4eac455c4f` |
| `tools/smoke_bundle_integrity.sh` | `9178421b97c3cdd675ac2320fdf64be72ccf30432b9acbe5cd4ac6bfa0178289` |
| `tools/traceability_check.sh` | `111de8f9c7522b04382ab97c760dc42df96aad1488a2e3900ae39e2d399388ea` |
| `tools/crypto_provider_ref/build.sh` | `72aaf55622828528b339e055d40c62d77ed72d7775754594d57fc929a8c8e5f0` |
| `tools/crypto_provider_ref/oclw_crypto_provider_ref.c` | `bf6978668fefe6e3edbe90a51016b759377815287b4c04c1352ed1d668fb1753` |

# Gate G1 Report (Rerun 02)

- UTC timestamp: 2026-02-09T18:25:37Z
- Commit (HEAD): ec60900b5e7fe754e5610d9270de51c13781dcaa

## Build

```text
$ gprbuild -P tests/tests.gpr
gprbuild: "smoke_platforms" up to date
gprbuild: "smoke_core" up to date
```

## Run: smoke_platforms

```text
$ ./tests/bin/smoke_platforms
platform_count_reported= 0
platform_count_used= 0
INFO no platforms: CL_PLATFORM_NOT_FOUND_KHR
```

## Run: smoke_core

```text
$ ./tests/bin/smoke_core
platform_capacity= 16
platform_count_used= 0
INFO no platforms: CL_PLATFORM_NOT_FOUND_KHR
```

## Exit Codes

```text
build_exit_code=0
smoke_platforms_exit_code=0
smoke_core_exit_code=0
```

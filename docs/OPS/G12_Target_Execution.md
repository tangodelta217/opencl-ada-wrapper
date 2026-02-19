# G12 Target Execution (Intel AOCL + AMD/XRT)

## Scope
This guide defines how to execute G12 target acceptance harnesses for two stacks:

- Intel AOCL: `tools/g12_target_intel_aocl_check.sh`
- AMD/XRT: `tools/g12_target_amd_xrt_check.sh`

Both harnesses are designed to be safe on non-target hosts:

- If the stack is not installed or incomplete, they return `RESULT=SKIP` and exit `0`.
- If the stack is detected, they run a target-oriented subset and generate acceptance evidence.

## Prerequisites
- Repository built artifacts available (`tests/bin/*`), or allow harness preflight to attempt:
  - `gprbuild -P tests/tests.gpr -p`
- OpenCL ICD installed for the target stack.
- For signature/strict checks, reference plugin build support (`gcc`) is recommended.

## Intel AOCL flow
Run:

```bash
cd /path/to/opencl-ada-wrapper
tools/g12_target_intel_aocl_check.sh
```

Generated evidence:

- `docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/Acceptance_Report.md`
- Logs in the same directory (`00_context.log` .. `12_bench_rt_pack_add1.log`).

Detection gates (summary):

- Intel/AOCL ICD evidence
- Intel runtime evidence
- AOCL tool or typical AOCL env vars

Executed subset when detected:

- `smoke_platforms`
- `smoke_rt_strict_policy`
- `bench_rt_pack_add1`

## AMD/XRT flow
Run:

```bash
cd /path/to/opencl-ada-wrapper
tools/g12_target_amd_xrt_check.sh
```

Generated evidence:

- `docs/VV/Execution_Logs/GATES/G12_AMD_XRT/rerun_01/Acceptance_Report.md`
- Logs in the same directory (`00_context.log` .. `12_bench_rt_pack_add1.log`).

Detection gates (summary):

- XRT/AMD ICD or runtime evidence
- XRT tooling or typical XRT env vars
- Captures `XCL_EMULATION_MODE` if present

Executed subset when detected:

- `smoke_platforms`
- `smoke_rt_strict_policy`
- `bench_rt_pack_add1`

## Acceptance criteria for target run
For a detected stack, acceptance is `PASS` when all subset commands:

- exit with code `0`, and
- emit `RESULT=PASS`.

Otherwise acceptance is `FAIL`.

## Notes for HW execution
- Use absolute, CM-controlled plugin paths in real RT environments.
- Keep pack directories and caches isolated per run (scripts already do this).
- If running on shared systems, archive the generated gate directory as primary evidence.

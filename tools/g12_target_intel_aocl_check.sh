#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${REPO_ROOT}" ]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
cd "${REPO_ROOT}"

REPORT_DIR="${REPO_ROOT}/docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01"
mkdir -p "${REPORT_DIR}"

CONTEXT_LOG="${REPORT_DIR}/00_context.log"
DETECT_LOG="${REPORT_DIR}/01_detection.log"
PREFLIGHT_LOG="${REPORT_DIR}/02_preflight.log"
PLUGIN_LOG="${REPORT_DIR}/03_plugin.log"
PLATFORMS_LOG="${REPORT_DIR}/10_smoke_platforms.log"
STRICT_LOG="${REPORT_DIR}/11_smoke_rt_strict_policy.log"
BENCH_LOG="${REPORT_DIR}/12_bench_rt_pack_add1.log"

TS_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
TS_COMPACT="$(date -u +"%Y%m%dT%H%M%SZ")"
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || echo "unknown")"

{
  echo "timestamp_utc=${TS_ISO}"
  echo "head=${HEAD_SHA}"
  echo "repo_root=${REPO_ROOT}"
  uname -a
  echo "git_status_short_begin"
  git status --short || true
  echo "git_status_short_end"
} >"${CONTEXT_LOG}" 2>&1

contains_intel_icd=0
if [ -d /etc/OpenCL/vendors ]; then
  if ls /etc/OpenCL/vendors/*.icd >/dev/null 2>&1; then
    if grep -Eiq 'intel|aocl' /etc/OpenCL/vendors/*.icd 2>/dev/null; then
      contains_intel_icd=1
    fi
    if ls /etc/OpenCL/vendors/*.icd 2>/dev/null | grep -Eiq 'intel|aocl'; then
      contains_intel_icd=1
    fi
  fi
fi

has_intel_runtime=0
if ldconfig -p 2>/dev/null | grep -Eiq 'intel.*opencl|intelocl|aocl'; then
  has_intel_runtime=1
fi

has_aocl_tools=0
if command -v aoc >/dev/null 2>&1 || command -v aocl >/dev/null 2>&1; then
  has_aocl_tools=1
fi

has_aocl_env=0
if [ -n "${INTELFPGAOCLSDKROOT:-}" ] || [ -n "${AOCL_BOARD_PACKAGE_ROOT:-}" ]; then
  has_aocl_env=1
fi

{
  echo "stack=INTEL_AOCL"
  echo "contains_intel_icd=${contains_intel_icd}"
  echo "has_intel_runtime=${has_intel_runtime}"
  echo "has_aocl_tools=${has_aocl_tools}"
  echo "has_aocl_env=${has_aocl_env}"
  echo "INTELFPGAOCLSDKROOT=${INTELFPGAOCLSDKROOT:-<unset>}"
  echo "AOCL_BOARD_PACKAGE_ROOT=${AOCL_BOARD_PACKAGE_ROOT:-<unset>}"
  echo "icd_listing_begin"
  ls -la /etc/OpenCL/vendors 2>/dev/null || true
  echo "icd_listing_end"
  echo "icd_contents_begin"
  cat /etc/OpenCL/vendors/*.icd 2>/dev/null || true
  echo "icd_contents_end"
  echo "ldconfig_opencl_begin"
  ldconfig -p 2>/dev/null | grep -Ei 'opencl|intel|aocl' || true
  echo "ldconfig_opencl_end"
} >"${DETECT_LOG}" 2>&1

stack_present=0
if [ "${contains_intel_icd}" -eq 1 ] && [ "${has_intel_runtime}" -eq 1 ] && { [ "${has_aocl_tools}" -eq 1 ] || [ "${has_aocl_env}" -eq 1 ]; }; then
  stack_present=1
fi

REPORT_MD="${REPORT_DIR}/Acceptance_Report.md"

if [ "${stack_present}" -ne 1 ]; then
  cat >"${REPORT_MD}" <<EOF_REPORT
# G12 INTEL AOCL Target Acceptance Report

- UTC timestamp: ${TS_ISO}
- HEAD: ${HEAD_SHA}
- stack: INTEL_AOCL
- status: SKIP
- reason: stack_not_installed_or_incomplete

## Detection Summary
- contains_intel_icd=${contains_intel_icd}
- has_intel_runtime=${has_intel_runtime}
- has_aocl_tools=${has_aocl_tools}
- has_aocl_env=${has_aocl_env}

## Evidence
- docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/00_context.log
- docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/01_detection.log

## Final
- RESULT=SKIP
EOF_REPORT
  echo "RESULT=SKIP reason=stack_not_installed_or_incomplete"
  echo "report=${REPORT_MD}"
  exit 0
fi

find_exec() {
  local name="$1"
  local p="${REPO_ROOT}/tests/bin/${name}"
  if [ -x "${p}" ]; then
    echo "${p}"
    return 0
  fi
  find "${REPO_ROOT}" -type f -name "${name}" -executable -print -quit
}

SMOKE_PLATFORMS_EXEC="$(find_exec smoke_platforms || true)"
SMOKE_STRICT_EXEC="$(find_exec smoke_rt_strict_policy || true)"
BENCH_RT_EXEC="$(find_exec bench_rt_pack_add1 || true)"

{
  echo "smoke_platforms_exec=${SMOKE_PLATFORMS_EXEC:-<missing>}"
  echo "smoke_rt_strict_policy_exec=${SMOKE_STRICT_EXEC:-<missing>}"
  echo "bench_rt_pack_add1_exec=${BENCH_RT_EXEC:-<missing>}"
} >"${PREFLIGHT_LOG}" 2>&1

if [ -z "${SMOKE_PLATFORMS_EXEC}" ] || [ -z "${SMOKE_STRICT_EXEC}" ] || [ -z "${BENCH_RT_EXEC}" ]; then
  set +e
  gprbuild -P tests/tests.gpr -p >>"${PREFLIGHT_LOG}" 2>&1
  BUILD_RC=$?
  set -e
  echo "gprbuild_preflight_exit_code=${BUILD_RC}" >>"${PREFLIGHT_LOG}"

  SMOKE_PLATFORMS_EXEC="$(find_exec smoke_platforms || true)"
  SMOKE_STRICT_EXEC="$(find_exec smoke_rt_strict_policy || true)"
  BENCH_RT_EXEC="$(find_exec bench_rt_pack_add1 || true)"
fi

if [ -z "${SMOKE_PLATFORMS_EXEC}" ] || [ -z "${SMOKE_STRICT_EXEC}" ] || [ -z "${BENCH_RT_EXEC}" ]; then
  cat >"${REPORT_MD}" <<EOF_REPORT
# G12 INTEL AOCL Target Acceptance Report

- UTC timestamp: ${TS_ISO}
- HEAD: ${HEAD_SHA}
- stack: INTEL_AOCL
- status: FAIL
- reason: required_binaries_missing

## Evidence
- docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/02_preflight.log

## Final
- RESULT=FAIL
EOF_REPORT
  echo "RESULT=FAIL reason=required_binaries_missing"
  echo "report=${REPORT_MD}"
  exit 1
fi

CRYPTO_PLUGIN_SO="${REPO_ROOT}/tools/crypto_provider_ref/liboclw_crypto_provider_ref.so"
CRYPTO_PLUGIN_BUILD="${REPO_ROOT}/tools/crypto_provider_ref/build.sh"
CRYPTO_PLUGIN_PATH=""
if [ -x "${CRYPTO_PLUGIN_BUILD}" ]; then
  set +e
  bash "${CRYPTO_PLUGIN_BUILD}" >"${PLUGIN_LOG}" 2>&1
  PLUGIN_BUILD_RC=$?
  set -e
  echo "plugin_build_exit_code=${PLUGIN_BUILD_RC}" >>"${PLUGIN_LOG}"
else
  echo "plugin_build_script_missing=${CRYPTO_PLUGIN_BUILD}" >"${PLUGIN_LOG}"
fi
if [ -f "${CRYPTO_PLUGIN_SO}" ]; then
  if command -v realpath >/dev/null 2>&1; then
    CRYPTO_PLUGIN_PATH="$(realpath "${CRYPTO_PLUGIN_SO}")"
  else
    CRYPTO_PLUGIN_PATH="${CRYPTO_PLUGIN_SO}"
  fi
  echo "plugin_path=${CRYPTO_PLUGIN_PATH}" >>"${PLUGIN_LOG}"
else
  echo "plugin_path=<missing>" >>"${PLUGIN_LOG}"
fi

PACK_BASE="/tmp/oclw_g12_intel_${TS_COMPACT}"
mkdir -p "${PACK_BASE}/strict" "${PACK_BASE}/bench"
POCL_CACHE_DIR="/tmp/oclw_g12_intel_pocl_${TS_COMPACT}"
mkdir -p "${POCL_CACHE_DIR}"

run_case() {
  local log_path="$1"
  shift
  set +e
  env -i \
    PATH="${PATH}" \
    HOME="${HOME}" \
    POCL_CACHE_DIR="${POCL_CACHE_DIR}" \
    POCL_KERNEL_CACHE=0 \
    OCLW_CRYPTO_SYMBOL="oclw_kpack_verify_v1" \
    OCLW_CRYPTO_PLUGIN="${CRYPTO_PLUGIN_PATH}" \
    "$@" >"${log_path}" 2>&1
  local rc=$?
  set -e
  echo "${rc}"
}

PLATFORMS_RC="$(run_case "${PLATFORMS_LOG}" "${SMOKE_PLATFORMS_EXEC}")"
STRICT_RC="$(run_case "${STRICT_LOG}" env OCLW_PACK_DIR="${PACK_BASE}/strict" "${SMOKE_STRICT_EXEC}")"
BENCH_RC="$(run_case "${BENCH_LOG}" env OCLW_PACK_DIR="${PACK_BASE}/bench" OCLW_BENCH_WARMUP="5" OCLW_BENCH_ITERS="50" "${BENCH_RT_EXEC}")"

extract_result() {
  local log_path="$1"
  grep -E '^RESULT=' "${log_path}" | tail -n 1 || true
}

PLATFORMS_RESULT="$(extract_result "${PLATFORMS_LOG}")"
STRICT_RESULT="$(extract_result "${STRICT_LOG}")"
BENCH_RESULT="$(extract_result "${BENCH_LOG}")"

overall="PASS"
if [ "${PLATFORMS_RC}" -ne 0 ] || [[ "${PLATFORMS_RESULT}" != RESULT=PASS* ]]; then
  overall="FAIL"
fi
if [ "${STRICT_RC}" -ne 0 ] || [[ "${STRICT_RESULT}" != RESULT=PASS* ]]; then
  overall="FAIL"
fi
if [ "${BENCH_RC}" -ne 0 ] || [[ "${BENCH_RESULT}" != RESULT=PASS* ]]; then
  overall="FAIL"
fi

cat >"${REPORT_MD}" <<EOF_REPORT
# G12 INTEL AOCL Target Acceptance Report

- UTC timestamp: ${TS_ISO}
- HEAD: ${HEAD_SHA}
- stack: INTEL_AOCL
- target_pack_base: ${PACK_BASE}
- pocl_cache_dir: ${POCL_CACHE_DIR}
- plugin_path: ${CRYPTO_PLUGIN_PATH:-<unset>}

## Command Results

| Check | Exit code | RESULT line | Status |
| --- | ---: | --- | --- |
| smoke_platforms | ${PLATFORMS_RC} | ${PLATFORMS_RESULT:-<missing>} | $( [ "${PLATFORMS_RC}" -eq 0 ] && [[ "${PLATFORMS_RESULT}" == RESULT=PASS* ]] && echo PASS || echo FAIL ) |
| smoke_rt_strict_policy | ${STRICT_RC} | ${STRICT_RESULT:-<missing>} | $( [ "${STRICT_RC}" -eq 0 ] && [[ "${STRICT_RESULT}" == RESULT=PASS* ]] && echo PASS || echo FAIL ) |
| bench_rt_pack_add1 | ${BENCH_RC} | ${BENCH_RESULT:-<missing>} | $( [ "${BENCH_RC}" -eq 0 ] && [[ "${BENCH_RESULT}" == RESULT=PASS* ]] && echo PASS || echo FAIL ) |

## Evidence Logs
- docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/00_context.log
- docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/01_detection.log
- docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/02_preflight.log
- docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/03_plugin.log
- docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/10_smoke_platforms.log
- docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/11_smoke_rt_strict_policy.log
- docs/VV/Execution_Logs/GATES/G12_INTEL/rerun_01/12_bench_rt_pack_add1.log

## Final
- RESULT=${overall}
EOF_REPORT

if [ "${overall}" = "PASS" ]; then
  echo "RESULT=PASS"
  echo "report=${REPORT_MD}"
  exit 0
fi

echo "RESULT=FAIL"
echo "report=${REPORT_MD}"
exit 1

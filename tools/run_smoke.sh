#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${REPO_ROOT}" ]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
cd "${REPO_ROOT}"

LOG_DIR="${REPO_ROOT}/docs/VV/Execution_Logs/local"
mkdir -p "${LOG_DIR}"

"${REPO_ROOT}/tools/build.sh"

POCL_CACHE_CONFIGURED_BY_HARNESS=0
if [ -z "${POCL_CACHE_DIR:-}" ]; then
  export POCL_CACHE_DIR="${REPO_ROOT}/.pocl_kcache"
  mkdir -p "${POCL_CACHE_DIR}"
  POCL_CACHE_CONFIGURED_BY_HARNESS=1
fi

if [ "${POCL_CACHE_CONFIGURED_BY_HARNESS}" -eq 1 ] && [ -z "${POCL_KERNEL_CACHE:-}" ]; then
  export POCL_KERNEL_CACHE=0
fi

TIMESTAMP_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
SMOKE_LOG="${LOG_DIR}/${TIMESTAMP_UTC}_smoke_run.log"
PACK_DIR="${REPO_ROOT}/docs/VV/Execution_Logs/local/${TIMESTAMP_UTC}_kpack_add1"
MLP_PACK_DIR="${REPO_ROOT}/docs/VV/Execution_Logs/local/${TIMESTAMP_UTC}_kpack_ew_mlp"
export OCLW_PACK_DIR="${PACK_DIR}"
mkdir -p "${PACK_DIR}"
mkdir -p "${MLP_PACK_DIR}"
CRYPTO_PLUGIN_BUILD_SCRIPT="${REPO_ROOT}/tools/crypto_provider_ref/build.sh"
CRYPTO_PLUGIN_SO="${REPO_ROOT}/tools/crypto_provider_ref/liboclw_crypto_provider_ref.so"
TRACEABILITY_CHECK_SCRIPT="${REPO_ROOT}/tools/traceability_check.sh"
SMOKE_BUNDLE_INTEGRITY_SCRIPT="${REPO_ROOT}/tools/smoke_bundle_integrity.sh"

find_smoke_executable() {
  local smoke_name="$1"
  local default_path="${REPO_ROOT}/tests/bin/${smoke_name}"

  if [ -x "${default_path}" ]; then
    echo "${default_path}"
    return 0
  fi

  find "${REPO_ROOT}" -name "${smoke_name}" -type f -executable -print -quit
}

{
  echo "=== Smoke Run Start ==="
  echo "timestamp_utc=${TIMESTAMP_UTC}"
  echo "repo_root=${REPO_ROOT}"
  echo "pack_dir=${PACK_DIR}"
  echo "mlp_pack_dir=${MLP_PACK_DIR}"
  echo "oclw_pack_dir=${OCLW_PACK_DIR}"
  echo "pocl_cache_dir=${POCL_CACHE_DIR:-<unset>}"
  echo "pocl_kernel_cache=${POCL_KERNEL_CACHE:-<unset>}"
  echo "pocl_cache_configured_by_harness=${POCL_CACHE_CONFIGURED_BY_HARNESS}"
} | tee -a "${SMOKE_LOG}"

CRYPTO_PLUGIN_BUILD_EXIT_CODE=0
CRYPTO_PLUGIN_PATH=""
CRYPTO_PLUGIN_SYMBOL="oclw_kpack_verify_v1"
if [ -f "${CRYPTO_PLUGIN_BUILD_SCRIPT}" ]; then
  echo "\$ ${CRYPTO_PLUGIN_BUILD_SCRIPT}" | tee -a "${SMOKE_LOG}"
  set +e
  bash "${CRYPTO_PLUGIN_BUILD_SCRIPT}" >> "${SMOKE_LOG}" 2>&1
  CRYPTO_PLUGIN_BUILD_EXIT_CODE=$?
  set -e
  echo "crypto_plugin_build_exit_code=${CRYPTO_PLUGIN_BUILD_EXIT_CODE}" | tee -a "${SMOKE_LOG}"
else
  echo "INFO crypto_plugin_build_script_not_found=${CRYPTO_PLUGIN_BUILD_SCRIPT}" | tee -a "${SMOKE_LOG}"
fi

if [ -f "${CRYPTO_PLUGIN_SO}" ]; then
  if command -v realpath >/dev/null 2>&1; then
    CRYPTO_PLUGIN_PATH="$(realpath "${CRYPTO_PLUGIN_SO}")"
  else
    CRYPTO_PLUGIN_PATH="${CRYPTO_PLUGIN_SO}"
  fi
  if [ -z "${OCLW_RT_PLUGIN_ALLOWLIST:-}" ]; then
    export OCLW_RT_PLUGIN_ALLOWLIST="$(dirname "${CRYPTO_PLUGIN_PATH}")"
  fi
  echo "oclw_crypto_plugin=${CRYPTO_PLUGIN_PATH}" | tee -a "${SMOKE_LOG}"
  echo "oclw_crypto_symbol=${CRYPTO_PLUGIN_SYMBOL}" | tee -a "${SMOKE_LOG}"
  echo "oclw_rt_plugin_allowlist=${OCLW_RT_PLUGIN_ALLOWLIST}" | tee -a "${SMOKE_LOG}"
else
  echo "INFO crypto_plugin_so_not_found=${CRYPTO_PLUGIN_SO}" | tee -a "${SMOKE_LOG}"
fi

FUZZ_ITERS_DEFAULT="${OCLW_FUZZ_ITERS:-500}"
FUZZ_SEED_DEFAULT="${OCLW_FUZZ_SEED:-1}"
echo "fuzz_iters_default=${FUZZ_ITERS_DEFAULT}" | tee -a "${SMOKE_LOG}"
echo "fuzz_seed_default=${FUZZ_SEED_DEFAULT}" | tee -a "${SMOKE_LOG}"

SMOKE_PLATFORMS_EXEC="$(find_smoke_executable "smoke_platforms")"
SMOKE_CORE_EXEC="$(find_smoke_executable "smoke_core")"
GEN_PACK_ADD1_EXEC="$(find_smoke_executable "gen_pack_add1")"
GEN_PACK_EW_MLP_EXEC="$(find_smoke_executable "gen_pack_ew_mlp")"
SMOKE_RT_LOAD_PACK_ADD1_EXEC="$(find_smoke_executable "smoke_rt_load_pack_add1")"
SMOKE_RT_LOAD_PACK_EW_MLP_EXEC="$(find_smoke_executable "smoke_rt_load_pack_ew_mlp")"
SMOKE_RT_NEGATIVE_CASES_EXEC="$(find_smoke_executable "smoke_rt_negative_cases")"
SMOKE_RT_FS_ATTACK_CASES_EXEC="$(find_smoke_executable "smoke_rt_fs_attack_cases")"
SMOKE_RT_PACK_SYMLINK_ESCAPE_EXEC="$(find_smoke_executable "smoke_rt_pack_symlink_escape")"
SMOKE_RT_TOCTOU_MANIFEST_SWAP_EXEC="$(find_smoke_executable "smoke_rt_toctou_manifest_swap")"
SMOKE_RT_TOCTOU_BINARY_SWAP_EXEC="$(find_smoke_executable "smoke_rt_toctou_binary_swap")"
SMOKE_RT_SIGNATURE_ENFORCEMENT_EXEC="$(find_smoke_executable "smoke_rt_signature_enforcement")"
SMOKE_RT_SIGNATURE_PLUGIN_EXEC="$(find_smoke_executable "smoke_rt_signature_plugin")"
SMOKE_CRYPTO_PROVIDER_CONFORMANCE_EXEC="$(find_smoke_executable "smoke_crypto_provider_conformance")"
SMOKE_RT_STRICT_POLICY_EXEC="$(find_smoke_executable "smoke_rt_strict_policy")"
SMOKE_RT_BUILD_OPTIONS_POLICY_EXEC="$(find_smoke_executable "smoke_rt_build_options_policy")"
SMOKE_RT_NO_HEAP_AFTER_INIT_EXEC="$(find_smoke_executable "smoke_rt_no_heap_after_init")"
SMOKE_RT_ANTI_ROLLBACK_EXEC="$(find_smoke_executable "smoke_rt_anti_rollback")"
SMOKE_RT_UNTRUSTED_PLUGIN_EXEC="$(find_smoke_executable "smoke_rt_untrusted_plugin")"
SMOKE_RT_PLUGIN_ALLOWLIST_POLICY_EXEC="$(find_smoke_executable "smoke_rt_plugin_allowlist_policy")"
SMOKE_CONSTANT_TIME_COMPARE_EXEC="$(find_smoke_executable "smoke_constant_time_compare")"
SMOKE_FUZZ_KPACK_PARSER_EXEC="$(find_smoke_executable "smoke_fuzz_kpack_parser")"
BENCH_ADD1_EXEC="$(find_smoke_executable "bench_add1")"
BENCH_PIPELINE_H2D_KERNEL_D2H_EXEC="$(find_smoke_executable "bench_pipeline_h2d_kernel_d2h")"
BENCH_RT_PACK_ADD1_EXEC="$(find_smoke_executable "bench_rt_pack_add1")"
BENCH_RT_PACK_EW_MLP_EXEC="$(find_smoke_executable "bench_rt_pack_ew_mlp")"
BENCH_TRANSFERS_H2D_D2H_EXEC="$(find_smoke_executable "bench_transfers_h2d_d2h")"
BENCH_BATCHING_ADD1_EXEC="$(find_smoke_executable "bench_batching_add1")"
SMOKE_BUFFER_ROUNDTRIP_EXEC="$(find_smoke_executable "smoke_buffer_roundtrip")"
SMOKE_IMAGE_ROUNDTRIP_EXEC="$(find_smoke_executable "smoke_image_roundtrip")"
SMOKE_KERNEL_ADD1_EXEC="$(find_smoke_executable "smoke_kernel_add1")"
SMOKE_EW_MLP_INFERENCE_EXEC="$(find_smoke_executable "smoke_ew_mlp_inference")"
SMOKE_PROGRAM_IL_PATH_EXEC="$(find_smoke_executable "smoke_program_il_path")"
SMOKE_PACK_CATALOG_SELECTION_EXEC="$(find_smoke_executable "smoke_pack_catalog_selection")"
SMOKE_PROGRAM_BINARIES_MULTI_DEVICE_EXEC="$(find_smoke_executable "smoke_program_binaries_multi_device")"
SMOKE_PROGRAM_BINARIES_SUBDEVICES_EXEC="$(find_smoke_executable "smoke_program_binaries_subdevices")"
SMOKE_PROGRAM_BINARY_ROUNDTRIP_EXEC="$(find_smoke_executable "smoke_program_binary_roundtrip")"
MISSING_BINARIES=0

if [ -z "${SMOKE_PLATFORMS_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_platforms"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_CORE_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_core"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${GEN_PACK_ADD1_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: gen_pack_add1"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${GEN_PACK_EW_MLP_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: gen_pack_ew_mlp"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_LOAD_PACK_ADD1_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_load_pack_add1"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_LOAD_PACK_EW_MLP_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_load_pack_ew_mlp"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_NEGATIVE_CASES_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_negative_cases"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_FS_ATTACK_CASES_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_fs_attack_cases"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_PACK_SYMLINK_ESCAPE_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_pack_symlink_escape"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_TOCTOU_MANIFEST_SWAP_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_toctou_manifest_swap"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_TOCTOU_BINARY_SWAP_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_toctou_binary_swap"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_SIGNATURE_ENFORCEMENT_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_signature_enforcement"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_SIGNATURE_PLUGIN_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_signature_plugin"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_CRYPTO_PROVIDER_CONFORMANCE_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_crypto_provider_conformance"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_STRICT_POLICY_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_strict_policy"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_BUILD_OPTIONS_POLICY_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_build_options_policy"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_NO_HEAP_AFTER_INIT_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_no_heap_after_init"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_ANTI_ROLLBACK_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_anti_rollback"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_UNTRUSTED_PLUGIN_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_untrusted_plugin"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_RT_PLUGIN_ALLOWLIST_POLICY_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_rt_plugin_allowlist_policy"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_CONSTANT_TIME_COMPARE_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_constant_time_compare"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_FUZZ_KPACK_PARSER_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_fuzz_kpack_parser"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${BENCH_ADD1_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: bench_add1"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${BENCH_PIPELINE_H2D_KERNEL_D2H_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: bench_pipeline_h2d_kernel_d2h"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${BENCH_RT_PACK_ADD1_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: bench_rt_pack_add1"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${BENCH_RT_PACK_EW_MLP_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: bench_rt_pack_ew_mlp"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${BENCH_TRANSFERS_H2D_D2H_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: bench_transfers_h2d_d2h"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${BENCH_BATCHING_ADD1_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: bench_batching_add1"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_BUFFER_ROUNDTRIP_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_buffer_roundtrip"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_IMAGE_ROUNDTRIP_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_image_roundtrip"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_KERNEL_ADD1_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_kernel_add1"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_EW_MLP_INFERENCE_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_ew_mlp_inference"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_PROGRAM_IL_PATH_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_program_il_path"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_PACK_CATALOG_SELECTION_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_pack_catalog_selection"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_PROGRAM_BINARY_ROUNDTRIP_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_program_binary_roundtrip"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_PROGRAM_BINARIES_MULTI_DEVICE_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_program_binaries_multi_device"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ -z "${SMOKE_PROGRAM_BINARIES_SUBDEVICES_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_program_binaries_subdevices"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ ! -x "${TRACEABILITY_CHECK_SCRIPT}" ]; then
  {
    echo "ERROR missing executable traceability checker: ${TRACEABILITY_CHECK_SCRIPT}"
    echo "hint: verify tools/traceability_check.sh exists and is executable"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ ! -x "${SMOKE_BUNDLE_INTEGRITY_SCRIPT}" ]; then
  {
    echo "ERROR missing executable bundle integrity smoke: ${SMOKE_BUNDLE_INTEGRITY_SCRIPT}"
    echo "hint: verify tools/smoke_bundle_integrity.sh exists and is executable"
  } | tee -a "${SMOKE_LOG}"
  MISSING_BINARIES=1
fi

if [ "${MISSING_BINARIES}" -ne 0 ]; then
  echo "smoke_log=${SMOKE_LOG}" | tee -a "${SMOKE_LOG}"
  echo "=== Smoke Run End ===" | tee -a "${SMOKE_LOG}"
  exit 1
fi

{
  echo "smoke_platforms_executable=${SMOKE_PLATFORMS_EXEC}"
  echo "smoke_core_executable=${SMOKE_CORE_EXEC}"
  echo "gen_pack_add1_executable=${GEN_PACK_ADD1_EXEC}"
  echo "gen_pack_ew_mlp_executable=${GEN_PACK_EW_MLP_EXEC}"
  echo "smoke_rt_load_pack_add1_executable=${SMOKE_RT_LOAD_PACK_ADD1_EXEC}"
  echo "smoke_rt_load_pack_ew_mlp_executable=${SMOKE_RT_LOAD_PACK_EW_MLP_EXEC}"
  echo "smoke_rt_negative_cases_executable=${SMOKE_RT_NEGATIVE_CASES_EXEC}"
  echo "smoke_rt_fs_attack_cases_executable=${SMOKE_RT_FS_ATTACK_CASES_EXEC}"
  echo "smoke_rt_pack_symlink_escape_executable=${SMOKE_RT_PACK_SYMLINK_ESCAPE_EXEC}"
  echo "smoke_rt_toctou_manifest_swap_executable=${SMOKE_RT_TOCTOU_MANIFEST_SWAP_EXEC}"
  echo "smoke_rt_toctou_binary_swap_executable=${SMOKE_RT_TOCTOU_BINARY_SWAP_EXEC}"
  echo "smoke_rt_signature_enforcement_executable=${SMOKE_RT_SIGNATURE_ENFORCEMENT_EXEC}"
  echo "smoke_rt_signature_plugin_executable=${SMOKE_RT_SIGNATURE_PLUGIN_EXEC}"
  echo "smoke_crypto_provider_conformance_executable=${SMOKE_CRYPTO_PROVIDER_CONFORMANCE_EXEC}"
  echo "smoke_rt_strict_policy_executable=${SMOKE_RT_STRICT_POLICY_EXEC}"
  echo "smoke_rt_build_options_policy_executable=${SMOKE_RT_BUILD_OPTIONS_POLICY_EXEC}"
  echo "smoke_rt_no_heap_after_init_executable=${SMOKE_RT_NO_HEAP_AFTER_INIT_EXEC}"
  echo "smoke_rt_anti_rollback_executable=${SMOKE_RT_ANTI_ROLLBACK_EXEC}"
  echo "smoke_rt_untrusted_plugin_executable=${SMOKE_RT_UNTRUSTED_PLUGIN_EXEC}"
  echo "smoke_rt_plugin_allowlist_policy_executable=${SMOKE_RT_PLUGIN_ALLOWLIST_POLICY_EXEC}"
  echo "smoke_constant_time_compare_executable=${SMOKE_CONSTANT_TIME_COMPARE_EXEC}"
  echo "smoke_fuzz_kpack_parser_executable=${SMOKE_FUZZ_KPACK_PARSER_EXEC}"
  echo "bench_add1_executable=${BENCH_ADD1_EXEC}"
  echo "bench_pipeline_h2d_kernel_d2h_executable=${BENCH_PIPELINE_H2D_KERNEL_D2H_EXEC}"
  echo "bench_rt_pack_add1_executable=${BENCH_RT_PACK_ADD1_EXEC}"
  echo "bench_rt_pack_ew_mlp_executable=${BENCH_RT_PACK_EW_MLP_EXEC}"
  echo "bench_transfers_h2d_d2h_executable=${BENCH_TRANSFERS_H2D_D2H_EXEC}"
  echo "bench_batching_add1_executable=${BENCH_BATCHING_ADD1_EXEC}"
  echo "smoke_buffer_roundtrip_executable=${SMOKE_BUFFER_ROUNDTRIP_EXEC}"
  echo "smoke_image_roundtrip_executable=${SMOKE_IMAGE_ROUNDTRIP_EXEC}"
  echo "smoke_kernel_add1_executable=${SMOKE_KERNEL_ADD1_EXEC}"
  echo "smoke_ew_mlp_inference_executable=${SMOKE_EW_MLP_INFERENCE_EXEC}"
  echo "smoke_program_il_path_executable=${SMOKE_PROGRAM_IL_PATH_EXEC}"
  echo "smoke_pack_catalog_selection_executable=${SMOKE_PACK_CATALOG_SELECTION_EXEC}"
  echo "smoke_program_binaries_multi_device_executable=${SMOKE_PROGRAM_BINARIES_MULTI_DEVICE_EXEC}"
  echo "smoke_program_binaries_subdevices_executable=${SMOKE_PROGRAM_BINARIES_SUBDEVICES_EXEC}"
  echo "smoke_program_binary_roundtrip_executable=${SMOKE_PROGRAM_BINARY_ROUNDTRIP_EXEC}"
  echo "traceability_check_script=${TRACEABILITY_CHECK_SCRIPT}"
  echo "smoke_bundle_integrity_script=${SMOKE_BUNDLE_INTEGRITY_SCRIPT}"
} | tee -a "${SMOKE_LOG}"

run_and_log_smoke() {
  local smoke_name="$1"
  local smoke_exec="$2"

  echo "\$ ${smoke_exec}" | tee -a "${SMOKE_LOG}"
  set +e
  "${smoke_exec}" 2>&1 | tee -a "${SMOKE_LOG}"
  local smoke_rc="${PIPESTATUS[0]}"
  set -e
  echo "${smoke_name}_exit_code=${smoke_rc}" | tee -a "${SMOKE_LOG}"
  return "${smoke_rc}"
}

run_and_log_smoke_with_env() {
  local smoke_name="$1"
  local smoke_exec="$2"
  shift 2

  echo "\$ env $* ${smoke_exec}" | tee -a "${SMOKE_LOG}"
  set +e
  env "$@" "${smoke_exec}" 2>&1 | tee -a "${SMOKE_LOG}"
  local smoke_rc="${PIPESTATUS[0]}"
  set -e
  echo "${smoke_name}_exit_code=${smoke_rc}" | tee -a "${SMOKE_LOG}"
  return "${smoke_rc}"
}

OVERALL_RC=0
GEN_PACK_ADD1_RC=0
GEN_PACK_EW_MLP_RC=0
SMOKE_RT_LOAD_PACK_ADD1_RC=0
SMOKE_RT_LOAD_PACK_EW_MLP_RC=0
SMOKE_RT_NEGATIVE_CASES_RC=0
SMOKE_RT_FS_ATTACK_CASES_RC=0
SMOKE_RT_PACK_SYMLINK_ESCAPE_RC=0
SMOKE_RT_TOCTOU_MANIFEST_SWAP_RC=0
SMOKE_RT_TOCTOU_BINARY_SWAP_RC=0
SMOKE_RT_SIGNATURE_ENFORCEMENT_RC=0
SMOKE_RT_SIGNATURE_PLUGIN_RC=0
SMOKE_CRYPTO_PROVIDER_CONFORMANCE_RC=0
SMOKE_RT_STRICT_POLICY_RC=0
SMOKE_RT_BUILD_OPTIONS_POLICY_RC=0
SMOKE_RT_NO_HEAP_AFTER_INIT_RC=0
SMOKE_RT_ANTI_ROLLBACK_RC=0
SMOKE_RT_UNTRUSTED_PLUGIN_RC=0
SMOKE_RT_PLUGIN_ALLOWLIST_POLICY_RC=0
SMOKE_CONSTANT_TIME_COMPARE_RC=0
SMOKE_FUZZ_KPACK_PARSER_RC=0
TRACEABILITY_CHECK_RC=0
SMOKE_BUNDLE_INTEGRITY_RC=0
BENCH_ADD1_RC=0
BENCH_PIPELINE_H2D_KERNEL_D2H_RC=0
BENCH_RT_PACK_ADD1_RC=0
BENCH_RT_PACK_EW_MLP_RC=0
BENCH_TRANSFERS_H2D_D2H_RC=0
BENCH_BATCHING_ADD1_RC=0
SMOKE_PROGRAM_BINARIES_MULTI_DEVICE_RC=0
SMOKE_PROGRAM_BINARIES_SUBDEVICES_RC=0
SMOKE_IMAGE_ROUNDTRIP_RC=0
SMOKE_EW_MLP_INFERENCE_RC=0
SMOKE_PROGRAM_IL_PATH_RC=0
SMOKE_PACK_CATALOG_SELECTION_RC=0
run_and_log_smoke "smoke_platforms" "${SMOKE_PLATFORMS_EXEC}" || OVERALL_RC=$?
run_and_log_smoke "smoke_core" "${SMOKE_CORE_EXEC}" || OVERALL_RC=$?
run_and_log_smoke "gen_pack_add1" "${GEN_PACK_ADD1_EXEC}" || GEN_PACK_ADD1_RC=$?
if [ "${GEN_PACK_ADD1_RC}" -ne 0 ]; then
  OVERALL_RC="${GEN_PACK_ADD1_RC}"
fi
run_and_log_smoke_with_env \
  "gen_pack_ew_mlp" \
  "${GEN_PACK_EW_MLP_EXEC}" \
  OCLW_PACK_DIR="${MLP_PACK_DIR}" \
  || GEN_PACK_EW_MLP_RC=$?
if [ "${GEN_PACK_EW_MLP_RC}" -ne 0 ]; then
  OVERALL_RC="${GEN_PACK_EW_MLP_RC}"
fi
run_and_log_smoke "smoke_rt_load_pack_add1" "${SMOKE_RT_LOAD_PACK_ADD1_EXEC}" || SMOKE_RT_LOAD_PACK_ADD1_RC=$?
if [ "${SMOKE_RT_LOAD_PACK_ADD1_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_LOAD_PACK_ADD1_RC}"
fi
run_and_log_smoke "smoke_rt_load_pack_ew_mlp" "${SMOKE_RT_LOAD_PACK_EW_MLP_EXEC}" || SMOKE_RT_LOAD_PACK_EW_MLP_RC=$?
if [ "${SMOKE_RT_LOAD_PACK_EW_MLP_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_LOAD_PACK_EW_MLP_RC}"
fi
run_and_log_smoke "smoke_rt_negative_cases" "${SMOKE_RT_NEGATIVE_CASES_EXEC}" || SMOKE_RT_NEGATIVE_CASES_RC=$?
if [ "${SMOKE_RT_NEGATIVE_CASES_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_NEGATIVE_CASES_RC}"
fi
run_and_log_smoke "smoke_rt_fs_attack_cases" "${SMOKE_RT_FS_ATTACK_CASES_EXEC}" || SMOKE_RT_FS_ATTACK_CASES_RC=$?
if [ "${SMOKE_RT_FS_ATTACK_CASES_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_FS_ATTACK_CASES_RC}"
fi
run_and_log_smoke "smoke_rt_pack_symlink_escape" "${SMOKE_RT_PACK_SYMLINK_ESCAPE_EXEC}" || SMOKE_RT_PACK_SYMLINK_ESCAPE_RC=$?
if [ "${SMOKE_RT_PACK_SYMLINK_ESCAPE_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_PACK_SYMLINK_ESCAPE_RC}"
fi
run_and_log_smoke "smoke_rt_toctou_manifest_swap" "${SMOKE_RT_TOCTOU_MANIFEST_SWAP_EXEC}" || SMOKE_RT_TOCTOU_MANIFEST_SWAP_RC=$?
if [ "${SMOKE_RT_TOCTOU_MANIFEST_SWAP_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_TOCTOU_MANIFEST_SWAP_RC}"
fi
run_and_log_smoke "smoke_rt_toctou_binary_swap" "${SMOKE_RT_TOCTOU_BINARY_SWAP_EXEC}" || SMOKE_RT_TOCTOU_BINARY_SWAP_RC=$?
if [ "${SMOKE_RT_TOCTOU_BINARY_SWAP_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_TOCTOU_BINARY_SWAP_RC}"
fi
run_and_log_smoke "smoke_rt_signature_enforcement" "${SMOKE_RT_SIGNATURE_ENFORCEMENT_EXEC}" || SMOKE_RT_SIGNATURE_ENFORCEMENT_RC=$?
if [ "${SMOKE_RT_SIGNATURE_ENFORCEMENT_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_SIGNATURE_ENFORCEMENT_RC}"
fi
run_and_log_smoke "smoke_rt_signature_plugin" "${SMOKE_RT_SIGNATURE_PLUGIN_EXEC}" || SMOKE_RT_SIGNATURE_PLUGIN_RC=$?
if [ "${SMOKE_RT_SIGNATURE_PLUGIN_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_SIGNATURE_PLUGIN_RC}"
fi
if [ -n "${CRYPTO_PLUGIN_PATH}" ]; then
  run_and_log_smoke_with_env \
    "smoke_crypto_provider_conformance" \
    "${SMOKE_CRYPTO_PROVIDER_CONFORMANCE_EXEC}" \
    OCLW_CRYPTO_PLUGIN="${CRYPTO_PLUGIN_PATH}" \
    OCLW_CRYPTO_SYMBOL="${CRYPTO_PLUGIN_SYMBOL}" \
    || SMOKE_CRYPTO_PROVIDER_CONFORMANCE_RC=$?
else
  run_and_log_smoke "smoke_crypto_provider_conformance" "${SMOKE_CRYPTO_PROVIDER_CONFORMANCE_EXEC}" || SMOKE_CRYPTO_PROVIDER_CONFORMANCE_RC=$?
fi
if [ "${SMOKE_CRYPTO_PROVIDER_CONFORMANCE_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_CRYPTO_PROVIDER_CONFORMANCE_RC}"
fi
run_and_log_smoke "smoke_rt_strict_policy" "${SMOKE_RT_STRICT_POLICY_EXEC}" || SMOKE_RT_STRICT_POLICY_RC=$?
if [ "${SMOKE_RT_STRICT_POLICY_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_STRICT_POLICY_RC}"
fi
run_and_log_smoke "smoke_rt_build_options_policy" "${SMOKE_RT_BUILD_OPTIONS_POLICY_EXEC}" || SMOKE_RT_BUILD_OPTIONS_POLICY_RC=$?
if [ "${SMOKE_RT_BUILD_OPTIONS_POLICY_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_BUILD_OPTIONS_POLICY_RC}"
fi
run_and_log_smoke "smoke_rt_no_heap_after_init" "${SMOKE_RT_NO_HEAP_AFTER_INIT_EXEC}" || SMOKE_RT_NO_HEAP_AFTER_INIT_RC=$?
if [ "${SMOKE_RT_NO_HEAP_AFTER_INIT_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_NO_HEAP_AFTER_INIT_RC}"
fi
run_and_log_smoke "smoke_rt_anti_rollback" "${SMOKE_RT_ANTI_ROLLBACK_EXEC}" || SMOKE_RT_ANTI_ROLLBACK_RC=$?
if [ "${SMOKE_RT_ANTI_ROLLBACK_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_ANTI_ROLLBACK_RC}"
fi
run_and_log_smoke "bench_add1" "${BENCH_ADD1_EXEC}" || BENCH_ADD1_RC=$?
if [ "${BENCH_ADD1_RC}" -ne 0 ]; then
  OVERALL_RC="${BENCH_ADD1_RC}"
fi
run_and_log_smoke "bench_pipeline_h2d_kernel_d2h" "${BENCH_PIPELINE_H2D_KERNEL_D2H_EXEC}" || BENCH_PIPELINE_H2D_KERNEL_D2H_RC=$?
if [ "${BENCH_PIPELINE_H2D_KERNEL_D2H_RC}" -ne 0 ]; then
  OVERALL_RC="${BENCH_PIPELINE_H2D_KERNEL_D2H_RC}"
fi
if [ -n "${CRYPTO_PLUGIN_PATH}" ]; then
  run_and_log_smoke_with_env \
    "bench_rt_pack_add1" \
    "${BENCH_RT_PACK_ADD1_EXEC}" \
    OCLW_CRYPTO_PLUGIN="${CRYPTO_PLUGIN_PATH}" \
    OCLW_CRYPTO_SYMBOL="${CRYPTO_PLUGIN_SYMBOL}" \
    || BENCH_RT_PACK_ADD1_RC=$?
else
  run_and_log_smoke "bench_rt_pack_add1" "${BENCH_RT_PACK_ADD1_EXEC}" || BENCH_RT_PACK_ADD1_RC=$?
fi
if [ "${BENCH_RT_PACK_ADD1_RC}" -ne 0 ]; then
  OVERALL_RC="${BENCH_RT_PACK_ADD1_RC}"
fi
if [ "${OCLW_RUN_BENCH:-0}" = "1" ]; then
  run_and_log_smoke "bench_rt_pack_ew_mlp" "${BENCH_RT_PACK_EW_MLP_EXEC}" || BENCH_RT_PACK_EW_MLP_RC=$?
  if [ "${BENCH_RT_PACK_EW_MLP_RC}" -ne 0 ]; then
    OVERALL_RC="${BENCH_RT_PACK_EW_MLP_RC}"
  fi
else
  echo "INFO bench_rt_pack_ew_mlp=SKIP_DISABLED (set OCLW_RUN_BENCH=1)" | tee -a "${SMOKE_LOG}"
fi
run_and_log_smoke "bench_transfers_h2d_d2h" "${BENCH_TRANSFERS_H2D_D2H_EXEC}" || BENCH_TRANSFERS_H2D_D2H_RC=$?
if [ "${BENCH_TRANSFERS_H2D_D2H_RC}" -ne 0 ]; then
  OVERALL_RC="${BENCH_TRANSFERS_H2D_D2H_RC}"
fi
run_and_log_smoke "bench_batching_add1" "${BENCH_BATCHING_ADD1_EXEC}" || BENCH_BATCHING_ADD1_RC=$?
if [ "${BENCH_BATCHING_ADD1_RC}" -ne 0 ]; then
  OVERALL_RC="${BENCH_BATCHING_ADD1_RC}"
fi
run_and_log_smoke "smoke_rt_untrusted_plugin" "${SMOKE_RT_UNTRUSTED_PLUGIN_EXEC}" || SMOKE_RT_UNTRUSTED_PLUGIN_RC=$?
if [ "${SMOKE_RT_UNTRUSTED_PLUGIN_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_UNTRUSTED_PLUGIN_RC}"
fi
run_and_log_smoke "smoke_rt_plugin_allowlist_policy" "${SMOKE_RT_PLUGIN_ALLOWLIST_POLICY_EXEC}" || SMOKE_RT_PLUGIN_ALLOWLIST_POLICY_RC=$?
if [ "${SMOKE_RT_PLUGIN_ALLOWLIST_POLICY_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_RT_PLUGIN_ALLOWLIST_POLICY_RC}"
fi
run_and_log_smoke "smoke_constant_time_compare" "${SMOKE_CONSTANT_TIME_COMPARE_EXEC}" || SMOKE_CONSTANT_TIME_COMPARE_RC=$?
if [ "${SMOKE_CONSTANT_TIME_COMPARE_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_CONSTANT_TIME_COMPARE_RC}"
fi
run_and_log_smoke_with_env \
  "smoke_fuzz_kpack_parser" \
  "${SMOKE_FUZZ_KPACK_PARSER_EXEC}" \
  OCLW_FUZZ_ITERS="${FUZZ_ITERS_DEFAULT}" \
  OCLW_FUZZ_SEED="${FUZZ_SEED_DEFAULT}" \
  || SMOKE_FUZZ_KPACK_PARSER_RC=$?
if [ "${SMOKE_FUZZ_KPACK_PARSER_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_FUZZ_KPACK_PARSER_RC}"
fi
run_and_log_smoke "traceability_check" "${TRACEABILITY_CHECK_SCRIPT}" || TRACEABILITY_CHECK_RC=$?
if [ "${TRACEABILITY_CHECK_RC}" -ne 0 ]; then
  OVERALL_RC="${TRACEABILITY_CHECK_RC}"
fi
run_and_log_smoke "smoke_bundle_integrity" "${SMOKE_BUNDLE_INTEGRITY_SCRIPT}" || SMOKE_BUNDLE_INTEGRITY_RC=$?
if [ "${SMOKE_BUNDLE_INTEGRITY_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_BUNDLE_INTEGRITY_RC}"
fi
run_and_log_smoke "smoke_buffer_roundtrip" "${SMOKE_BUFFER_ROUNDTRIP_EXEC}" || OVERALL_RC=$?
run_and_log_smoke "smoke_image_roundtrip" "${SMOKE_IMAGE_ROUNDTRIP_EXEC}" || SMOKE_IMAGE_ROUNDTRIP_RC=$?
if [ "${SMOKE_IMAGE_ROUNDTRIP_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_IMAGE_ROUNDTRIP_RC}"
fi
run_and_log_smoke "smoke_kernel_add1" "${SMOKE_KERNEL_ADD1_EXEC}" || OVERALL_RC=$?
run_and_log_smoke "smoke_ew_mlp_inference" "${SMOKE_EW_MLP_INFERENCE_EXEC}" || SMOKE_EW_MLP_INFERENCE_RC=$?
if [ "${SMOKE_EW_MLP_INFERENCE_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_EW_MLP_INFERENCE_RC}"
fi
run_and_log_smoke "smoke_program_il_path" "${SMOKE_PROGRAM_IL_PATH_EXEC}" || SMOKE_PROGRAM_IL_PATH_RC=$?
if [ "${SMOKE_PROGRAM_IL_PATH_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_PROGRAM_IL_PATH_RC}"
fi
run_and_log_smoke "smoke_pack_catalog_selection" "${SMOKE_PACK_CATALOG_SELECTION_EXEC}" || SMOKE_PACK_CATALOG_SELECTION_RC=$?
if [ "${SMOKE_PACK_CATALOG_SELECTION_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_PACK_CATALOG_SELECTION_RC}"
fi
run_and_log_smoke "smoke_program_binaries_multi_device" "${SMOKE_PROGRAM_BINARIES_MULTI_DEVICE_EXEC}" || SMOKE_PROGRAM_BINARIES_MULTI_DEVICE_RC=$?
if [ "${SMOKE_PROGRAM_BINARIES_MULTI_DEVICE_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_PROGRAM_BINARIES_MULTI_DEVICE_RC}"
fi
run_and_log_smoke "smoke_program_binaries_subdevices" "${SMOKE_PROGRAM_BINARIES_SUBDEVICES_EXEC}" || SMOKE_PROGRAM_BINARIES_SUBDEVICES_RC=$?
if [ "${SMOKE_PROGRAM_BINARIES_SUBDEVICES_RC}" -ne 0 ]; then
  OVERALL_RC="${SMOKE_PROGRAM_BINARIES_SUBDEVICES_RC}"
fi
run_and_log_smoke "smoke_program_binary_roundtrip" "${SMOKE_PROGRAM_BINARY_ROUNDTRIP_EXEC}" || OVERALL_RC=$?

echo "gen_pack_add1_exit_code=${GEN_PACK_ADD1_RC}" | tee -a "${SMOKE_LOG}"
echo "gen_pack_ew_mlp_exit_code=${GEN_PACK_EW_MLP_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_load_pack_add1_exit_code=${SMOKE_RT_LOAD_PACK_ADD1_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_load_pack_ew_mlp_exit_code=${SMOKE_RT_LOAD_PACK_EW_MLP_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_negative_cases_exit_code=${SMOKE_RT_NEGATIVE_CASES_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_fs_attack_cases_exit_code=${SMOKE_RT_FS_ATTACK_CASES_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_pack_symlink_escape_exit_code=${SMOKE_RT_PACK_SYMLINK_ESCAPE_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_toctou_manifest_swap_exit_code=${SMOKE_RT_TOCTOU_MANIFEST_SWAP_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_toctou_binary_swap_exit_code=${SMOKE_RT_TOCTOU_BINARY_SWAP_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_signature_enforcement_exit_code=${SMOKE_RT_SIGNATURE_ENFORCEMENT_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_signature_plugin_exit_code=${SMOKE_RT_SIGNATURE_PLUGIN_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_crypto_provider_conformance_exit_code=${SMOKE_CRYPTO_PROVIDER_CONFORMANCE_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_strict_policy_exit_code=${SMOKE_RT_STRICT_POLICY_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_build_options_policy_exit_code=${SMOKE_RT_BUILD_OPTIONS_POLICY_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_no_heap_after_init_exit_code=${SMOKE_RT_NO_HEAP_AFTER_INIT_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_anti_rollback_exit_code=${SMOKE_RT_ANTI_ROLLBACK_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_untrusted_plugin_exit_code=${SMOKE_RT_UNTRUSTED_PLUGIN_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_rt_plugin_allowlist_policy_exit_code=${SMOKE_RT_PLUGIN_ALLOWLIST_POLICY_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_constant_time_compare_exit_code=${SMOKE_CONSTANT_TIME_COMPARE_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_fuzz_kpack_parser_exit_code=${SMOKE_FUZZ_KPACK_PARSER_RC}" | tee -a "${SMOKE_LOG}"
echo "traceability_check_exit_code=${TRACEABILITY_CHECK_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_bundle_integrity_exit_code=${SMOKE_BUNDLE_INTEGRITY_RC}" | tee -a "${SMOKE_LOG}"
echo "bench_add1_exit_code=${BENCH_ADD1_RC}" | tee -a "${SMOKE_LOG}"
echo "bench_pipeline_h2d_kernel_d2h_exit_code=${BENCH_PIPELINE_H2D_KERNEL_D2H_RC}" | tee -a "${SMOKE_LOG}"
echo "bench_rt_pack_add1_exit_code=${BENCH_RT_PACK_ADD1_RC}" | tee -a "${SMOKE_LOG}"
echo "bench_rt_pack_ew_mlp_exit_code=${BENCH_RT_PACK_EW_MLP_RC}" | tee -a "${SMOKE_LOG}"
echo "bench_transfers_h2d_d2h_exit_code=${BENCH_TRANSFERS_H2D_D2H_RC}" | tee -a "${SMOKE_LOG}"
echo "bench_batching_add1_exit_code=${BENCH_BATCHING_ADD1_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_image_roundtrip_exit_code=${SMOKE_IMAGE_ROUNDTRIP_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_ew_mlp_inference_exit_code=${SMOKE_EW_MLP_INFERENCE_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_program_il_path_exit_code=${SMOKE_PROGRAM_IL_PATH_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_pack_catalog_selection_exit_code=${SMOKE_PACK_CATALOG_SELECTION_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_program_binaries_multi_device_exit_code=${SMOKE_PROGRAM_BINARIES_MULTI_DEVICE_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_program_binaries_subdevices_exit_code=${SMOKE_PROGRAM_BINARIES_SUBDEVICES_RC}" | tee -a "${SMOKE_LOG}"
echo "pack_dir=${PACK_DIR}" | tee -a "${SMOKE_LOG}"
echo "mlp_pack_dir=${MLP_PACK_DIR}" | tee -a "${SMOKE_LOG}"
echo "smoke_exit_code=${OVERALL_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_log=${SMOKE_LOG}" | tee -a "${SMOKE_LOG}"
echo "=== Smoke Run End ===" | tee -a "${SMOKE_LOG}"

exit "${OVERALL_RC}"

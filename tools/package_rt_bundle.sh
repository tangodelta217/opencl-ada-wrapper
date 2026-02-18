#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${REPO_ROOT}" ]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
cd "${REPO_ROOT}"

TIMESTAMP_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
DIST_ROOT="${REPO_ROOT}/dist"
BUNDLE_NAME="oclw_rt_bundle_${TIMESTAMP_UTC}"
BUNDLE_DIR="${DIST_ROOT}/${BUNDLE_NAME}"
LOG_DIR="${BUNDLE_DIR}/logs"
DOCS_DIR="${BUNDLE_DIR}/docs"
EXAMPLE_PACK_DIR="${BUNDLE_DIR}/example_pack"

mkdir -p "${LOG_DIR}" "${DOCS_DIR}/OPS" "${DOCS_DIR}/CM" "${DOCS_DIR}/ARCH"

echo "INFO repo_root=${REPO_ROOT}"
echo "INFO bundle_dir=${BUNDLE_DIR}"
echo "INFO timestamp_utc=${TIMESTAMP_UTC}"

echo "INFO build_opencl_wrapper_start"
gprbuild -P opencl_wrapper.gpr -p 2>&1 | tee "${LOG_DIR}/build_opencl_wrapper.log"
echo "INFO build_opencl_wrapper_done"

echo "INFO build_tests_start"
gprbuild -P tests/tests.gpr -p 2>&1 | tee "${LOG_DIR}/build_tests.log"
echo "INFO build_tests_done"

cp "docs/OPS/RT_Deployment_Guide.md" "${DOCS_DIR}/OPS/"
cp "docs/CM/Delivery_Content.md" "${DOCS_DIR}/CM/"
cp "docs/CM/SBOM_Minimal.md" "${DOCS_DIR}/CM/"
cp "tools/crypto_provider_ref/README.md" \
  "${DOCS_DIR}/ARCH/Crypto_Plugin_C_ABI_Contract.md"

cat > "${BUNDLE_DIR}/BUNDLE_INFO.txt" <<EOF
bundle_name=${BUNDLE_NAME}
timestamp_utc=${TIMESTAMP_UTC}
git_head=$(git rev-parse HEAD)
notes=reference_plugin_is_not_included_as_production_artifact
EOF

PACK_STATUS="SKIP_missing_gen_pack_add1"
if [ -x "${REPO_ROOT}/tests/bin/gen_pack_add1" ]; then
  echo "INFO generating_example_pack_start"
  export OCLW_PACK_DIR="${EXAMPLE_PACK_DIR}"
  mkdir -p "${EXAMPLE_PACK_DIR}"
  set +e
  "${REPO_ROOT}/tests/bin/gen_pack_add1" \
    > "${LOG_DIR}/gen_pack_add1.log" 2>&1
  PACK_RC=$?
  set -e
  if [ "${PACK_RC}" -eq 0 ]; then
    PACK_STATUS="PASS"
    echo "INFO generating_example_pack_done"
  else
    PACK_STATUS="FAIL_exit_${PACK_RC}"
    echo "WARN generating_example_pack_failed exit=${PACK_RC}"
  fi
else
  echo "WARN tests/bin/gen_pack_add1 not found; skipping example pack"
fi

echo "example_pack_status=${PACK_STATUS}" >> "${BUNDLE_DIR}/BUNDLE_INFO.txt"

CHECKSUM_TOOL=""
CHECKSUM_FILE=""
if command -v sha256sum >/dev/null 2>&1; then
  CHECKSUM_TOOL="sha256sum"
  CHECKSUM_FILE="${BUNDLE_DIR}/CHECKSUMS.sha256"
elif command -v md5sum >/dev/null 2>&1; then
  CHECKSUM_TOOL="md5sum"
  CHECKSUM_FILE="${BUNDLE_DIR}/CHECKSUMS.md5"
else
  echo "ERROR no checksum tool found (sha256sum/md5sum)"
  exit 1
fi

(
  cd "${BUNDLE_DIR}"
  {
    echo "# checksum_tool=${CHECKSUM_TOOL}"
    echo "# generated_utc=${TIMESTAMP_UTC}"
    find . -type f \
      ! -name "$(basename "${CHECKSUM_FILE}")" \
      -print0 \
      | sort -z \
      | xargs -0 "${CHECKSUM_TOOL}"
  } > "$(basename "${CHECKSUM_FILE}")"
)

if [ "${CHECKSUM_TOOL}" = "md5sum" ]; then
  echo "checksum_tool_note=md5sum_used_sha256sum_not_available" \
    >> "${BUNDLE_DIR}/BUNDLE_INFO.txt"
fi

ARCHIVE_PATH="${DIST_ROOT}/${BUNDLE_NAME}.tar.gz"
tar -C "${DIST_ROOT}" -czf "${ARCHIVE_PATH}" "${BUNDLE_NAME}"

echo "bundle_archive=${ARCHIVE_PATH}"
echo "bundle_checksums=${CHECKSUM_FILE}"
echo "bundle_example_pack_status=${PACK_STATUS}"

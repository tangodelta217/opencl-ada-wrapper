#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
export TZ=UTC

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${REPO_ROOT}" ]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
cd "${REPO_ROOT}"

DIST_ROOT="${REPO_ROOT}/dist"
SBOM_FULL_SCRIPT="${REPO_ROOT}/tools/gen_sbom_full.sh"

REPRODUCIBLE=0
if [ "${OCLW_REPRODUCIBLE:-0}" = "1" ]; then
  REPRODUCIBLE=1
fi

REPRO_SOURCE_DATE_EPOCH_DEFAULT="1700000000"
if [ "${REPRODUCIBLE}" -eq 1 ]; then
  SOURCE_DATE_EPOCH_DEFAULT="${REPRO_SOURCE_DATE_EPOCH_DEFAULT}"
else
  SOURCE_DATE_EPOCH_DEFAULT="$(git -C "${REPO_ROOT}" log -1 --format=%ct 2>/dev/null || date -u +%s)"
fi
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-${SOURCE_DATE_EPOCH_DEFAULT}}"
if ! [[ "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]]; then
  echo "ERROR invalid SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
  exit 1
fi

if [ "${REPRODUCIBLE}" -eq 1 ]; then
  BUNDLE_NAME="oclw_rt_bundle_reproducible"
  TIMESTAMP_UTC="$(date -u -d "@${SOURCE_DATE_EPOCH}" +"%Y%m%dT%H%M%SZ")"
  TIMESTAMP_ISO_UTC="$(date -u -d "@${SOURCE_DATE_EPOCH}" +"%Y-%m-%dT%H:%M:%SZ")"
else
  TIMESTAMP_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
  TIMESTAMP_ISO_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  BUNDLE_NAME="oclw_rt_bundle_${TIMESTAMP_UTC}"
fi

BUNDLE_DIR="${DIST_ROOT}/${BUNDLE_NAME}"
LOG_DIR="${BUNDLE_DIR}/logs"
DOCS_DIR="${BUNDLE_DIR}/docs"
EXAMPLE_PACK_DIR="${BUNDLE_DIR}/example_pack"
CHECKSUM_FILE="${BUNDLE_DIR}/CHECKSUMS.sha256"

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "ERROR sha256sum not found"
  exit 1
fi
if ! command -v gzip >/dev/null 2>&1; then
  echo "ERROR gzip not found"
  exit 1
fi

if [ -d "${BUNDLE_DIR}" ]; then
  rm -rf -- "${BUNDLE_DIR}"
fi
mkdir -p "${LOG_DIR}" "${DOCS_DIR}/OPS" "${DOCS_DIR}/CM" "${DOCS_DIR}/ARCH"

echo "INFO repo_root=${REPO_ROOT}"
echo "INFO bundle_dir=${BUNDLE_DIR}"
echo "INFO timestamp_utc=${TIMESTAMP_UTC}"
echo "INFO reproducible=${REPRODUCIBLE}"
echo "INFO source_date_epoch=${SOURCE_DATE_EPOCH}"

echo "INFO build_opencl_wrapper_start"
gprbuild -P opencl_wrapper.gpr -p 2>&1 | tee "${LOG_DIR}/build_opencl_wrapper.log"
echo "INFO build_opencl_wrapper_done"

echo "INFO build_tests_start"
gprbuild -P tests/tests.gpr -p 2>&1 | tee "${LOG_DIR}/build_tests.log"
echo "INFO build_tests_done"

echo "INFO generate_sbom_full_start"
OCLW_REPRODUCIBLE="${REPRODUCIBLE}" SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
  "${SBOM_FULL_SCRIPT}" 2>&1 | tee "${LOG_DIR}/gen_sbom_full.log"
echo "INFO generate_sbom_full_done"

cp "docs/OPS/RT_Deployment_Guide.md" "${DOCS_DIR}/OPS/"
cp "docs/CM/Delivery_Content.md" "${DOCS_DIR}/CM/"
cp "docs/CM/SBOM_Minimal.md" "${DOCS_DIR}/CM/"
cp "docs/CM/SBOM_Full.md" "${DOCS_DIR}/CM/"
cp "tools/crypto_provider_ref/README.md" \
  "${DOCS_DIR}/ARCH/Crypto_Plugin_C_ABI_Contract.md"

cat > "${BUNDLE_DIR}/BUNDLE_INFO.txt" <<EOF
bundle_name=${BUNDLE_NAME}
timestamp_utc=${TIMESTAMP_ISO_UTC}
source_date_epoch=${SOURCE_DATE_EPOCH}
reproducible=${REPRODUCIBLE}
git_head=$(git rev-parse HEAD)
notes=reference_plugin_is_not_included_as_production_artifact
EOF

PACK_STATUS="SKIP_reproducible_mode"
if [ "${REPRODUCIBLE}" -eq 0 ] && [ -x "${REPO_ROOT}/tests/bin/gen_pack_add1" ]; then
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
elif [ "${REPRODUCIBLE}" -eq 0 ]; then
  PACK_STATUS="SKIP_missing_gen_pack_add1"
  echo "WARN tests/bin/gen_pack_add1 not found; skipping example pack"
fi
echo "example_pack_status=${PACK_STATUS}" >> "${BUNDLE_DIR}/BUNDLE_INFO.txt"

(
  cd "${BUNDLE_DIR}"
  {
    echo "# checksum_tool=sha256sum"
    echo "# reproducible=${REPRODUCIBLE}"
    echo "# source_date_epoch=${SOURCE_DATE_EPOCH}"
    find . -type f \
      ! -name "$(basename "${CHECKSUM_FILE}")" \
      -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 sha256sum
  } > "$(basename "${CHECKSUM_FILE}")"
)

ARCHIVE_PATH="${DIST_ROOT}/${BUNDLE_NAME}.tar.gz"
if [ "${REPRODUCIBLE}" -eq 1 ]; then
  if ! tar --version 2>/dev/null | head -n 1 | grep -qi "gnu tar"; then
    echo "ERROR reproducible_mode_requires_gnu_tar"
    exit 1
  fi

  ARCHIVE_TMP_TAR="$(mktemp "${DIST_ROOT}/${BUNDLE_NAME}.XXXXXX.tar")"
  trap 'rm -f -- "${ARCHIVE_TMP_TAR}"' EXIT

  tar \
    --sort=name \
    --mtime="@${SOURCE_DATE_EPOCH}" \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    --pax-option=delete=atime,delete=ctime \
    -C "${DIST_ROOT}" -cf "${ARCHIVE_TMP_TAR}" "${BUNDLE_NAME}"

  gzip -n -9 -c "${ARCHIVE_TMP_TAR}" > "${ARCHIVE_PATH}"
  rm -f -- "${ARCHIVE_TMP_TAR}"
  trap - EXIT
else
  tar -C "${DIST_ROOT}" -czf "${ARCHIVE_PATH}" "${BUNDLE_NAME}"
fi

echo "bundle_archive=${ARCHIVE_PATH}"
echo "bundle_checksums=${CHECKSUM_FILE}"
echo "bundle_example_pack_status=${PACK_STATUS}"

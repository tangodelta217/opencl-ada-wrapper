#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${REPO_ROOT}" ]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
cd "${REPO_ROOT}"

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "RESULT=FAIL"
  echo "INFO reason=sha256sum_not_found"
  exit 1
fi

TIMESTAMP_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
LOCAL_LOG_DIR="${REPO_ROOT}/docs/VV/Execution_Logs/local"
mkdir -p "${LOCAL_LOG_DIR}"

PACKAGE_LOG="${LOCAL_LOG_DIR}/${TIMESTAMP_UTC}_package_rt_bundle_repro.log"
CHECKSUM_VERIFY_LOG="${LOCAL_LOG_DIR}/${TIMESTAMP_UTC}_bundle_checksum_verify.log"
EXTRACT_ROOT="/tmp/oclw_bundle_integrity_${TIMESTAMP_UTC}"
SOURCE_DATE_EPOCH_DEFAULT="$(git -C "${REPO_ROOT}" log -1 --format=%ct 2>/dev/null || date -u +%s)"

echo "INFO reproducible=1"
echo "INFO source_date_epoch=${SOURCE_DATE_EPOCH_DEFAULT}"

set +e
OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH_DEFAULT}" \
  "${REPO_ROOT}/tools/package_rt_bundle.sh" > "${PACKAGE_LOG}" 2>&1
PACKAGE_RC=$?
set -e

if [ "${PACKAGE_RC}" -ne 0 ]; then
  echo "RESULT=FAIL"
  echo "INFO package_rt_bundle_exit_code=${PACKAGE_RC}"
  echo "INFO package_log=${PACKAGE_LOG}"
  exit 1
fi

BUNDLE_ARCHIVE="$(awk -F= '/^bundle_archive=/{print $2}' "${PACKAGE_LOG}" | tail -n 1)"
if [ -z "${BUNDLE_ARCHIVE}" ] || [ ! -f "${BUNDLE_ARCHIVE}" ]; then
  echo "RESULT=FAIL"
  echo "INFO reason=bundle_archive_not_found"
  echo "INFO package_log=${PACKAGE_LOG}"
  exit 1
fi

rm -rf -- "${EXTRACT_ROOT}"
mkdir -p "${EXTRACT_ROOT}"
tar -xzf "${BUNDLE_ARCHIVE}" -C "${EXTRACT_ROOT}"

BUNDLE_NAME="$(basename "${BUNDLE_ARCHIVE}" .tar.gz)"
BUNDLE_DIR="${EXTRACT_ROOT}/${BUNDLE_NAME}"
CHECKSUM_FILE="${BUNDLE_DIR}/CHECKSUMS.sha256"

if [ ! -f "${CHECKSUM_FILE}" ]; then
  echo "RESULT=FAIL"
  echo "INFO reason=checksums_missing"
  echo "INFO bundle_archive=${BUNDLE_ARCHIVE}"
  exit 1
fi

set +e
(
  cd "${BUNDLE_DIR}"
  sha256sum -c "CHECKSUMS.sha256"
) > "${CHECKSUM_VERIFY_LOG}" 2>&1
VERIFY_RC=$?
set -e
if [ "${VERIFY_RC}" -ne 0 ]; then
  echo "RESULT=FAIL"
  echo "INFO reason=checksum_verification_failed"
  echo "INFO checksum_verify_log=${CHECKSUM_VERIFY_LOG}"
  echo "INFO bundle_archive=${BUNDLE_ARCHIVE}"
  exit 1
fi

REQUIRED_FILES=(
  "BUNDLE_INFO.txt"
  "CHECKSUMS.sha256"
  "docs/OPS/RT_Deployment_Guide.md"
  "docs/CM/Delivery_Content.md"
  "docs/CM/SBOM_Minimal.md"
  "docs/CM/SBOM_Full.md"
  "docs/ARCH/Crypto_Plugin_C_ABI_Contract.md"
)

MISSING_COUNT=0
for rel in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "${BUNDLE_DIR}/${rel}" ]; then
    echo "INFO missing_required_file=${rel}"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
done

if ! grep -q '^reproducible=1$' "${BUNDLE_DIR}/BUNDLE_INFO.txt"; then
  echo "RESULT=FAIL"
  echo "INFO reason=bundle_info_reproducible_flag_missing"
  echo "INFO bundle_archive=${BUNDLE_ARCHIVE}"
  exit 1
fi

if [ "${MISSING_COUNT}" -ne 0 ]; then
  echo "RESULT=FAIL"
  echo "INFO missing_required_count=${MISSING_COUNT}"
  echo "INFO bundle_archive=${BUNDLE_ARCHIVE}"
  exit 1
fi

echo "INFO bundle_archive=${BUNDLE_ARCHIVE}"
echo "INFO extracted_bundle_dir=${BUNDLE_DIR}"
echo "INFO checksum_verify_log=${CHECKSUM_VERIFY_LOG}"
echo "INFO missing_required_count=0"
echo "RESULT=PASS"

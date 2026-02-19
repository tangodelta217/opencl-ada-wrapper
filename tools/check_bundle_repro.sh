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

PACKAGE_SCRIPT="${REPO_ROOT}/tools/package_rt_bundle.sh"
if [ ! -x "${PACKAGE_SCRIPT}" ]; then
  echo "RESULT=FAIL"
  echo "INFO reason=missing_package_script"
  exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "RESULT=FAIL"
  echo "INFO reason=missing_sha256sum"
  exit 1
fi

SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1700000000}"
if ! [[ "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]]; then
  echo "RESULT=FAIL"
  echo "INFO reason=invalid_source_date_epoch"
  exit 1
fi

RUN1_LOG="${REPO_ROOT}/dist/check_bundle_repro_run1.log"
RUN2_LOG="${REPO_ROOT}/dist/check_bundle_repro_run2.log"
ARCHIVE_PATH="${REPO_ROOT}/dist/oclw_rt_bundle_reproducible.tar.gz"
TMP1="$(mktemp /tmp/oclw_bundle_repro_run1_XXXXXX.tar.gz)"
TMP2="$(mktemp /tmp/oclw_bundle_repro_run2_XXXXXX.tar.gz)"
trap 'rm -f -- "${TMP1}" "${TMP2}"' EXIT

set +e
OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
  "${PACKAGE_SCRIPT}" >"${RUN1_LOG}" 2>&1
RC1=$?
set -e
if [ "${RC1}" -ne 0 ] || [ ! -f "${ARCHIVE_PATH}" ]; then
  echo "RESULT=FAIL"
  echo "INFO reason=run1_failed"
  echo "INFO rc1=${RC1}"
  exit 1
fi
cp "${ARCHIVE_PATH}" "${TMP1}"

set +e
OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
  "${PACKAGE_SCRIPT}" >"${RUN2_LOG}" 2>&1
RC2=$?
set -e
if [ "${RC2}" -ne 0 ] || [ ! -f "${ARCHIVE_PATH}" ]; then
  echo "RESULT=FAIL"
  echo "INFO reason=run2_failed"
  echo "INFO rc2=${RC2}"
  exit 1
fi
cp "${ARCHIVE_PATH}" "${TMP2}"

SHA1="$(sha256sum "${TMP1}" | awk '{print $1}')"
SHA2="$(sha256sum "${TMP2}" | awk '{print $1}')"

echo "INFO source_date_epoch=${SOURCE_DATE_EPOCH}"
echo "INFO run1_log=${RUN1_LOG}"
echo "INFO run2_log=${RUN2_LOG}"
echo "INFO sha1=${SHA1}"
echo "INFO sha2=${SHA2}"

if [ "${SHA1}" = "${SHA2}" ]; then
  echo "RESULT=PASS"
  exit 0
fi

echo "RESULT=FAIL"
exit 1

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
mkdir -p "${DIST_ROOT}"

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
  BUNDLE_NAME="oclw_evidence_bundle_reproducible"
else
  TIMESTAMP_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
  BUNDLE_NAME="oclw_evidence_bundle_${TIMESTAMP_UTC}"
fi

BUNDLE_DIR="${DIST_ROOT}/${BUNDLE_NAME}"
ARCHIVE_PATH="${DIST_ROOT}/${BUNDLE_NAME}.tar.gz"
CHECKSUM_FILE="${BUNDLE_DIR}/CHECKSUMS.sha256"

for req in tar gzip sha256sum; do
  if ! command -v "${req}" >/dev/null 2>&1; then
    echo "ERROR missing_required_tool=${req}"
    exit 1
  fi
done

for f in README.md AGENTS.md opencl_wrapper.gpr; do
  if [ ! -f "${REPO_ROOT}/${f}" ]; then
    echo "ERROR missing_required_file=${f}"
    exit 1
  fi
done

if [ ! -d "${REPO_ROOT}/docs" ]; then
  echo "ERROR missing_required_dir=docs"
  exit 1
fi

if [ -d "${BUNDLE_DIR}" ]; then
  rm -rf -- "${BUNDLE_DIR}"
fi
mkdir -p "${BUNDLE_DIR}"

cp -a "${REPO_ROOT}/docs" "${BUNDLE_DIR}/docs"
cp "${REPO_ROOT}/README.md" "${BUNDLE_DIR}/README.md"
cp "${REPO_ROOT}/AGENTS.md" "${BUNDLE_DIR}/AGENTS.md"
cp "${REPO_ROOT}/opencl_wrapper.gpr" "${BUNDLE_DIR}/opencl_wrapper.gpr"

# Safety prune for temporary/cache content if present under selected trees.
find "${BUNDLE_DIR}" -type d \
  \( -name ".pocl_kcache" -o -name "__pycache__" -o -name ".cache" \) \
  -prune -exec rm -rf -- {} +
find "${BUNDLE_DIR}" -type f \
  \( -name "*.tmp" -o -name "*.swp" -o -name ".DS_Store" \) \
  -delete

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

ARCHIVE_SHA256="$(sha256sum "${ARCHIVE_PATH}" | awk '{print $1}')"

echo "bundle_dir=${BUNDLE_DIR}"
echo "bundle_archive=${ARCHIVE_PATH}"
echo "bundle_checksums=${CHECKSUM_FILE}"
echo "bundle_archive_sha256=${ARCHIVE_SHA256}"
echo "reproducible=${REPRODUCIBLE}"
echo "source_date_epoch=${SOURCE_DATE_EPOCH}"

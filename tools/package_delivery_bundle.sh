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

if [ "${OCLW_REPRODUCIBLE:-0}" != "1" ]; then
  echo "ERROR OCLW_REPRODUCIBLE=1 is required"
  exit 1
fi

if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
  echo "ERROR SOURCE_DATE_EPOCH is required"
  exit 1
fi
if ! [[ "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]]; then
  echo "ERROR invalid SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
  exit 1
fi

for req in tar gzip sha256sum; do
  if ! command -v "${req}" >/dev/null 2>&1; then
    echo "ERROR missing_required_tool=${req}"
    exit 1
  fi
done

if ! tar --version 2>/dev/null | head -n 1 | grep -qi "gnu tar"; then
  echo "ERROR reproducible_mode_requires_gnu_tar"
  exit 1
fi

DIST_DIR="${REPO_ROOT}/dist"
RT_BUNDLE="${DIST_DIR}/oclw_rt_bundle_reproducible.tar.gz"
EVID_BUNDLE="${DIST_DIR}/oclw_evidence_bundle_reproducible.tar.gz"
DELIVERY_STAGE="${DIST_DIR}/_delivery_stage"
DELIVERY_ARCHIVE="${DIST_DIR}/oclw_delivery_bundle_reproducible.tar.gz"
MANIFEST_PATH="${DELIVERY_STAGE}/DELIVERY_MANIFEST.txt"
CHECKSUMS_PATH="${DELIVERY_STAGE}/CHECKSUMS.sha256"

mkdir -p "${DIST_DIR}"

if [ ! -f "${RT_BUNDLE}" ]; then
  OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
    "${REPO_ROOT}/tools/package_rt_bundle.sh"
fi

if [ ! -f "${EVID_BUNDLE}" ]; then
  OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
    "${REPO_ROOT}/tools/package_evidence_bundle.sh"
fi

if [ ! -f "${RT_BUNDLE}" ]; then
  echo "ERROR missing_rt_bundle=${RT_BUNDLE}"
  exit 1
fi
if [ ! -f "${EVID_BUNDLE}" ]; then
  echo "ERROR missing_evidence_bundle=${EVID_BUNDLE}"
  exit 1
fi

rm -rf -- "${DELIVERY_STAGE}"
mkdir -p "${DELIVERY_STAGE}"

cp "${RT_BUNDLE}" "${DELIVERY_STAGE}/oclw_rt_bundle_reproducible.tar.gz"
cp "${EVID_BUNDLE}" "${DELIVERY_STAGE}/oclw_evidence_bundle_reproducible.tar.gz"

HEAD_SHA="$(git rev-parse HEAD)"
SOURCE_DATE_UTC="$(date -u -d "@${SOURCE_DATE_EPOCH}" +"%Y-%m-%dT%H:%M:%SZ")"

cat > "${MANIFEST_PATH}" <<EOF
delivery_bundle=oclw_delivery_bundle_reproducible.tar.gz
source_date_epoch=${SOURCE_DATE_EPOCH}
source_date_utc=${SOURCE_DATE_UTC}
git_head=${HEAD_SHA}
includes=oclw_rt_bundle_reproducible.tar.gz
includes=oclw_evidence_bundle_reproducible.tar.gz
checksum_file=CHECKSUMS.sha256
EOF

(
  cd "${DELIVERY_STAGE}"
  printf '%s\n' \
    "./DELIVERY_MANIFEST.txt" \
    "./oclw_evidence_bundle_reproducible.tar.gz" \
    "./oclw_rt_bundle_reproducible.tar.gz" \
    | LC_ALL=C sort \
    | xargs sha256sum > "$(basename "${CHECKSUMS_PATH}")"
)

TMP_TAR="$(mktemp "${DIST_DIR}/oclw_delivery_bundle_reproducible.XXXXXX.tar")"
trap 'rm -f -- "${TMP_TAR}"' EXIT

tar \
  --sort=name \
  --mtime="@${SOURCE_DATE_EPOCH}" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  --pax-option=delete=atime,delete=ctime \
  -C "${DIST_DIR}" -cf "${TMP_TAR}" "$(basename "${DELIVERY_STAGE}")"

gzip -n -9 -c "${TMP_TAR}" > "${DELIVERY_ARCHIVE}"
rm -f -- "${TMP_TAR}"
trap - EXIT

ARCHIVE_SHA256="$(sha256sum "${DELIVERY_ARCHIVE}" | awk '{print $1}')"

echo "delivery_archive=${DELIVERY_ARCHIVE}"
echo "delivery_archive_sha256=${ARCHIVE_SHA256}"
echo "delivery_stage=${DELIVERY_STAGE}"
echo "delivery_manifest=${MANIFEST_PATH}"
echo "delivery_checksums=${CHECKSUMS_PATH}"
echo "source_date_epoch=${SOURCE_DATE_EPOCH}"

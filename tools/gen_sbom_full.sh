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

OUT_FILE="${REPO_ROOT}/docs/CM/SBOM_Full.md"
REPRODUCIBLE=0
if [ "${OCLW_REPRODUCIBLE:-0}" = "1" ]; then
  REPRODUCIBLE=1
fi

SOURCE_DATE_EPOCH_DEFAULT="1700000000"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-${SOURCE_DATE_EPOCH_DEFAULT}}"
if ! [[ "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]]; then
  echo "ERROR invalid SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
  exit 1
fi

if [ "${REPRODUCIBLE}" -eq 1 ]; then
  GENERATED_UTC="$(date -u -d "@${SOURCE_DATE_EPOCH}" +"%Y-%m-%dT%H:%M:%SZ")"
else
  GENERATED_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
fi
GIT_HEAD="$(git -C "${REPO_ROOT}" rev-parse HEAD 2>/dev/null || echo "UNKNOWN")"

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "ERROR sha256sum not found"
  exit 1
fi

main_script_hash() {
  local rel_path="$1"
  local abs_path="${REPO_ROOT}/${rel_path}"
  if [ -f "${abs_path}" ]; then
    sha256sum "${abs_path}" | awk '{print $1}'
  else
    echo "MISSING"
  fi
}

print_command_preview() {
  local line_count="$1"
  shift
  local tmp_file
  tmp_file="$(mktemp)"
  if "$@" > "${tmp_file}" 2>&1; then
    :
  else
    :
  fi
  sed -n "1,${line_count}p" "${tmp_file}"
  rm -f -- "${tmp_file}"
}

{
  echo "# SBOM Full"
  echo
  echo "- generated_utc=${GENERATED_UTC}"
  echo "- git_head=${GIT_HEAD}"
  echo "- reproducible=${REPRODUCIBLE}"
  echo "- source_date_epoch=${SOURCE_DATE_EPOCH}"
  echo
  echo "## Toolchain Versions"
  echo '```text'
  if command -v gprbuild >/dev/null 2>&1; then
    print_command_preview 3 gprbuild --version
  else
    echo "gprbuild: not found"
  fi
  echo
  if command -v gnatls >/dev/null 2>&1; then
    print_command_preview 8 gnatls -v
  else
    echo "gnatls: not found"
  fi
  echo
  if command -v gcc >/dev/null 2>&1; then
    print_command_preview 20 gcc -v
  else
    echo "gcc: not found"
  fi
  echo '```'
  echo
  echo "## Runtime Libraries (OpenCL)"
  echo '```text'
  if command -v ldconfig >/dev/null 2>&1; then
    ldconfig -p 2>/dev/null | grep -i opencl | LC_ALL=C sort \
      || echo "no OpenCL entries found"
  else
    echo "ldconfig: not found"
  fi
  echo '```'
  echo
  echo "## Script Hashes (SHA-256)"
  echo
  echo "| Path | SHA-256 |"
  echo "|---|---|"
  for rel in \
    tools/build.sh \
    tools/run_smoke.sh \
    tools/package_rt_bundle.sh \
    tools/gen_sbom_full.sh \
    tools/smoke_bundle_integrity.sh \
    tools/traceability_check.sh \
    tools/crypto_provider_ref/build.sh \
    tools/crypto_provider_ref/oclw_crypto_provider_ref.c; do
    echo "| \`${rel}\` | \`$(main_script_hash "${rel}")\` |"
  done
} > "${OUT_FILE}"

echo "INFO sbom_full_path=${OUT_FILE}"

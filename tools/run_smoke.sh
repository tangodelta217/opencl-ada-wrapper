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

TIMESTAMP_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
SMOKE_LOG="${LOG_DIR}/${TIMESTAMP_UTC}_smoke_run.log"

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
} | tee -a "${SMOKE_LOG}"

SMOKE_PLATFORMS_EXEC="$(find_smoke_executable "smoke_platforms")"
SMOKE_CORE_EXEC="$(find_smoke_executable "smoke_core")"
SMOKE_BUFFER_ROUNDTRIP_EXEC="$(find_smoke_executable "smoke_buffer_roundtrip")"
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

if [ -z "${SMOKE_BUFFER_ROUNDTRIP_EXEC}" ]; then
  {
    echo "ERROR missing smoke executable: smoke_buffer_roundtrip"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
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
  echo "smoke_buffer_roundtrip_executable=${SMOKE_BUFFER_ROUNDTRIP_EXEC}"
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

OVERALL_RC=0
run_and_log_smoke "smoke_platforms" "${SMOKE_PLATFORMS_EXEC}" || OVERALL_RC=$?
run_and_log_smoke "smoke_core" "${SMOKE_CORE_EXEC}" || OVERALL_RC=$?
run_and_log_smoke "smoke_buffer_roundtrip" "${SMOKE_BUFFER_ROUNDTRIP_EXEC}" || OVERALL_RC=$?

echo "smoke_exit_code=${OVERALL_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_log=${SMOKE_LOG}" | tee -a "${SMOKE_LOG}"
echo "=== Smoke Run End ===" | tee -a "${SMOKE_LOG}"

exit "${OVERALL_RC}"

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
  if [ -x "${REPO_ROOT}/tests/bin/smoke_platforms" ]; then
    echo "${REPO_ROOT}/tests/bin/smoke_platforms"
    return 0
  fi

  find "${REPO_ROOT}" -name "smoke_platforms" -type f -executable -print -quit
}

SMOKE_EXEC="$(find_smoke_executable)"
if [ -z "${SMOKE_EXEC}" ]; then
  {
    echo "ERROR smoke executable not found"
    echo "hint: run 'gprbuild -P tests/tests.gpr' and verify output dirs"
  } | tee -a "${SMOKE_LOG}"
  exit 1
fi

{
  echo "=== Smoke Run Start ==="
  echo "timestamp_utc=${TIMESTAMP_UTC}"
  echo "repo_root=${REPO_ROOT}"
  echo "smoke_executable=${SMOKE_EXEC}"
  echo "\$ ${SMOKE_EXEC}"
} | tee -a "${SMOKE_LOG}"

set +e
"${SMOKE_EXEC}" 2>&1 | tee -a "${SMOKE_LOG}"
SMOKE_RC="${PIPESTATUS[0]}"
set -e

echo "smoke_exit_code=${SMOKE_RC}" | tee -a "${SMOKE_LOG}"
echo "smoke_log=${SMOKE_LOG}" | tee -a "${SMOKE_LOG}"
echo "=== Smoke Run End ===" | tee -a "${SMOKE_LOG}"

exit "${SMOKE_RC}"

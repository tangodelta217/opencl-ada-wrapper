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

TIMESTAMP_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
LOG_FILE="${LOG_DIR}/${TIMESTAMP_UTC}_build.log"

log() {
  echo "$*" | tee -a "${LOG_FILE}"
}

run_cmd() {
  log "\$ $*"
  set +e
  "$@" 2>&1 | tee -a "${LOG_FILE}"
  cmd_rc="${PIPESTATUS[0]}"
  set -e
  if [ "${cmd_rc}" -ne 0 ]; then
    log "ERROR command failed (${cmd_rc}): $*"
    log "build_log=${LOG_FILE}"
    exit "${cmd_rc}"
  fi
}

log "=== Build Start ==="
log "timestamp_utc=${TIMESTAMP_UTC}"
log "repo_root=${REPO_ROOT}"
log "uname=$(uname -a)"

if command -v gprbuild >/dev/null 2>&1; then
  run_cmd gprbuild --version
else
  log "ERROR gprbuild not found in PATH; install GNAT/gprbuild and retry."
  log "build_log=${LOG_FILE}"
  exit 127
fi

if command -v gnatls >/dev/null 2>&1; then
  run_cmd gnatls -v
else
  log "INFO gnatls not found in PATH"
fi

if command -v gcc >/dev/null 2>&1; then
  run_cmd gcc -v
else
  log "INFO gcc not found in PATH"
fi

run_cmd gprbuild -P opencl_wrapper.gpr -p
run_cmd gprbuild -P tests/tests.gpr -p

SMOKE_DEFAULT="${REPO_ROOT}/tests/bin/smoke_platforms"
if [ -x "${SMOKE_DEFAULT}" ]; then
  log "smoke_executable=${SMOKE_DEFAULT}"
else
  SMOKE_FOUND="$(find "${REPO_ROOT}" -name "smoke_platforms" -type f -executable -print -quit)"
  if [ -n "${SMOKE_FOUND}" ]; then
    log "smoke_executable=${SMOKE_FOUND}"
  else
    log "INFO smoke executable not found after build"
  fi
fi

log "build_log=${LOG_FILE}"
log "=== Build End ==="

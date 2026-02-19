#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${REPO_ROOT}" ]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
cd "${REPO_ROOT}"

if ! command -v gnatprove >/dev/null 2>&1; then
  echo "RESULT=SKIP"
  echo "INFO reason=gnatprove_not_found"
  exit 0
fi

echo "INFO gnatprove=FOUND"
echo "INFO project=opencl_wrapper.gpr"
echo "INFO mode=flow"

gnatprove -P opencl_wrapper.gpr --mode=flow -j0

echo "RESULT=PASS"

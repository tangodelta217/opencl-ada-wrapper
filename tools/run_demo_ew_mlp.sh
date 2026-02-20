#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${REPO_ROOT}" ]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
cd "${REPO_ROOT}"

echo "=== EW MLP Demo Build ==="
gprbuild -P tests/tests.gpr -p

echo "=== EW MLP Demo Run ==="
"${REPO_ROOT}/tests/bin/demo_ew_mlp"

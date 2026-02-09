#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

echo "[build] opencl_wrapper.gpr"
gprbuild -P opencl_wrapper.gpr -p

echo "[build] tests/tests.gpr"
gprbuild -P tests/tests.gpr -p

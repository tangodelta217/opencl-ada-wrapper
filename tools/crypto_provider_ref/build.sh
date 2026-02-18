#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

gcc -fPIC -shared -o liboclw_crypto_provider_ref.so oclw_crypto_provider_ref.c

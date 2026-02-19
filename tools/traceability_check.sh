#!/usr/bin/env bash
set -euo pipefail

TRACEABILITY_FILE="docs/REQ/Traceability.md"
GATES_ROOT="docs/VV/Execution_Logs/GATES"
SMOKE_DESIGN_GLOB="docs/VV/Smoke_Test_Design*.md"

missing_tests=()
missing_reports=()
checked_links=0
result="PASS"

join_csv() {
  local first=1
  local printed=0
  local item
  for item in "$@"; do
    if [ -z "${item}" ]; then
      continue
    fi

    if [ "${first}" -eq 1 ]; then
      printf "%s" "${item}"
      first=0
      printed=1
    else
      printf ",%s" "${item}"
      printed=1
    fi
  done

  if [ "${printed}" -eq 0 ]; then
    printf "<none>"
  fi
}

if [ ! -f "${TRACEABILITY_FILE}" ]; then
  echo "RESULT=FAIL"
  echo "INFO missing_tests=<traceability_file_missing>"
  echo "INFO missing_reports=<traceability_file_missing>"
  echo "INFO checked_links=0"
  exit 1
fi

mapfile -t test_ids < <(grep -oE 'OCLW-TST-[0-9]{4}' "${TRACEABILITY_FILE}" | sort -u)
mapfile -t gate_ids < <(grep -oE 'G[0-9]+[A-Z0-9]*' "${TRACEABILITY_FILE}" | sort -u)

for test_id in "${test_ids[@]:-}"; do
  if [ -z "${test_id}" ]; then
    continue
  fi

  checked_links=$((checked_links + 1))

  test_id_alt="${test_id//-/_}"
  found=0

  if rg -n -F "${test_id}" tests >/dev/null 2>&1; then
    found=1
  elif rg -n -F "${test_id_alt}" tests >/dev/null 2>&1; then
    found=1
  elif rg -n -F "${test_id}" ${SMOKE_DESIGN_GLOB} >/dev/null 2>&1; then
    found=1
  fi

  if [ "${found}" -ne 1 ]; then
    missing_tests+=("${test_id}")
    result="FAIL"
  fi
done

for gate_id in "${gate_ids[@]:-}"; do
  if [ -z "${gate_id}" ]; then
    continue
  fi

  checked_links=$((checked_links + 1))

  gate_dir="${GATES_ROOT}/${gate_id}"
  if [ ! -d "${gate_dir}" ]; then
    missing_reports+=("${gate_id}")
    result="FAIL"
    continue
  fi

  if ! find "${gate_dir}" -type f -name "*Report.md" | grep -q .; then
    missing_reports+=("${gate_id}")
    result="FAIL"
  fi
done

echo "RESULT=${result}"
echo "INFO missing_tests=$(join_csv "${missing_tests[@]:-}")"
echo "INFO missing_reports=$(join_csv "${missing_reports[@]:-}")"
echo "INFO checked_links=${checked_links}"

if [ "${result}" != "PASS" ]; then
  exit 1
fi

# Release Checklist RC

Use this checklist before freezing/publishing the RC baseline.

## 1) Build

Command:
```bash
gprbuild -P tests/tests.gpr
```
PASS criteria:
- Exit code `0`.

## 2) Smoke Suite

Command:
```bash
tools/run_smoke.sh
```
PASS criteria:
- Exit code `0`.
- Required hardening smokes are `RESULT=PASS` in run log:
  - `smoke_rt_pack_symlink_escape`
  - `smoke_rt_toctou_manifest_swap`
  - `smoke_rt_toctou_binary_swap`
  - `smoke_rt_plugin_allowlist_policy`

## 3) Reproducible Bundle

Commands:
```bash
OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH=1700000000 tools/package_rt_bundle.sh
sha256sum dist/oclw_rt_bundle_reproducible.tar.gz
OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH=1700000000 tools/package_rt_bundle.sh
sha256sum dist/oclw_rt_bundle_reproducible.tar.gz
```
PASS criteria:
- Both package commands return exit code `0`.
- SHA256 from both runs matches exactly.

## 4) Evidence Review

Commands:
```bash
cat docs/VV/Execution_Logs/GATES/G35/rerun_01/G35_Release_Candidate_Audit.md
cat docs/VV/Execution_Logs/GATES/G36/rerun_01/G36_TestSeam_Exclusion_Report.md
cat docs/VV/Execution_Logs/GATES/G37/rerun_01/G37_Evidence_Bundle_Report.md
cat docs/VV/Execution_Logs/GATES/G38/rerun_01/G38_Delivery_Bundle_Report.md
```
PASS criteria:
- G35 final result is `RESULT=PASS`.
- G36 final result is `RESULT=PASS`.
- G37 final result is `RESULT=PASS`.
- G38 final result is `RESULT=PASS`.

## 5) Evidence Bundle (G37)

Commands:
```bash
OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH=1700000000 tools/package_evidence_bundle.sh
sha256sum dist/oclw_evidence_bundle_reproducible.tar.gz
OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH=1700000000 tools/package_evidence_bundle.sh
sha256sum dist/oclw_evidence_bundle_reproducible.tar.gz
cat docs/VV/Execution_Logs/GATES/G37/rerun_01/G37_Evidence_Bundle_Report.md
```
PASS criteria:
- Both evidence bundle runs return exit code `0`.
- SHA256 from both runs matches exactly.
- G37 report final result is `RESULT=PASS`.

## 6) Delivery Bundle (G38, si existe)

Commands:
```bash
if [ -x tools/package_delivery_bundle.sh ]; then
  OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH=1700000000 tools/package_delivery_bundle.sh
  sha256sum dist/oclw_delivery_bundle_reproducible.tar.gz
  OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH=1700000000 tools/package_delivery_bundle.sh
  sha256sum dist/oclw_delivery_bundle_reproducible.tar.gz
  cat docs/VV/Execution_Logs/GATES/G38/rerun_01/G38_Delivery_Bundle_Report.md
else
  echo "INFO package_delivery_bundle.sh missing -> G38 optional"
fi
```
PASS criteria:
- If `tools/package_delivery_bundle.sh` exists:
  - Both delivery bundle runs return exit code `0`.
  - SHA256 from both runs matches exactly.
  - G38 report final result is `RESULT=PASS`.
- If it does not exist:
  - Mark G38 as optional/not applicable for this RC checklist run.

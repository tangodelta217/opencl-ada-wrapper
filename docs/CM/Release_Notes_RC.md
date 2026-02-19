# Release Notes RC

- Release ID: `OCLW v0.1.0-rc1`
- Commit (HEAD): `bdac2e785fc1934bfad826572b8b397ac9e4cb37`
- Date (UTC): `2026-02-19`

## Included Scope (High Level)

- RT no-JIT path with kernel packs and catalog selection flow.
- Reproducible bundle packaging path (`OCLW_REPRODUCIBLE=1`).
- Security hardening coverage and closure chain for G31..G34.
- Consolidated RC audit (G35) and test seam exclusion audit (G36).
- Reproducible evidence bundle (G37).
- Reproducible delivery bundle (G38).

## Primary Evidence

- G35 PASS (RC audit): `docs/VV/Execution_Logs/GATES/G35/rerun_01/G35_Release_Candidate_Audit.md`
- G36 PASS (seam exclusion): `docs/VV/Execution_Logs/GATES/G36/rerun_01/G36_TestSeam_Exclusion_Report.md`
- G37 PASS (evidence bundle reproducible): `docs/VV/Execution_Logs/GATES/G37/rerun_01/G37_Evidence_Bundle_Report.md`
- G38 PASS (delivery bundle reproducible, si existe; presente en este baseline): `docs/VV/Execution_Logs/GATES/G38/rerun_01/G38_Delivery_Bundle_Report.md`
- G35 closure: `docs/VV/Execution_Logs/GATES/G35/Closure.md`
- G36 closure: `docs/VV/Execution_Logs/GATES/G36/Closure.md`

## Dist Artifacts (RC1)

- `dist/oclw_rt_bundle_reproducible.tar.gz`
- `dist/oclw_evidence_bundle_reproducible.tar.gz`
- `dist/oclw_delivery_bundle_reproducible.tar.gz`

## Checksums / Integrity References

- RT bundle file-list checksums:
  `dist/oclw_rt_bundle_reproducible/CHECKSUMS.sha256`
- Evidence bundle file-list checksums:
  `dist/oclw_evidence_bundle_reproducible/CHECKSUMS.sha256`
- Delivery bundle staging checksums:
  `dist/_delivery_stage/CHECKSUMS.sha256`
- Reproducibility hash evidence:
  - G37 report (`sha1 == sha2`) for `oclw_evidence_bundle_reproducible.tar.gz`
  - G38 report (`sha1 == sha2`) for `oclw_delivery_bundle_reproducible.tar.gz`

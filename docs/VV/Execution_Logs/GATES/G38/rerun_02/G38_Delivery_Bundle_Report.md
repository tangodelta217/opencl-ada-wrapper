# Gate G38 Delivery Bundle Report (rerun_02)

- UTC timestamp: 2026-02-20T11:29:35Z
- HEAD: `374d9a880c9d58ead4e3bcda4beb588ef3956dcd`
- Reproducible mode: `OCLW_REPRODUCIBLE=1`, `SOURCE_DATE_EPOCH=1700000000`

## Commands

- `OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH=1700000000 tools/package_delivery_bundle.sh` (run 1)
- `OCLW_REPRODUCIBLE=1 SOURCE_DATE_EPOCH=1700000000 tools/package_delivery_bundle.sh` (run 2)

## Results

- run1 exit code: 0
- run2 exit code: 0
- bundle path: `dist/oclw_delivery_bundle_reproducible.tar.gz`
- sha1: `506254d4f580fe2dfdb13767c507ba5cebb6a6c3434b296f1baf2b701b7b5089`
- sha2: `506254d4f580fe2dfdb13767c507ba5cebb6a6c3434b296f1baf2b701b7b5089`
- compare: MATCH
- RESULT=PASS

## Logs

- `docs/VV/Execution_Logs/GATES/G38/rerun_02/01_run1.log`
- `docs/VV/Execution_Logs/GATES/G38/rerun_02/02_run2.log`
- `docs/VV/Execution_Logs/GATES/G38/rerun_02/03_sha_compare.log`

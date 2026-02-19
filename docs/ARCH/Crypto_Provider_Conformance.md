# Crypto Provider Conformance

## Objective

Validate that a crypto provider plugin (`.so`) conforms to the OCLW C ABI
contract used by RT signature verification.

This conformance check is implementation-agnostic: it works with the
reference plugin (`NOT CRYPTO`) and with a real provider.

## Smoke Test

Executable:

- `tests/bin/smoke_crypto_provider_conformance`

Required environment:

- `OCLW_CRYPTO_PLUGIN=<absolute_path_to_plugin.so>`
- Optional: `OCLW_CRYPTO_SYMBOL=oclw_kpack_verify_v1`

Behavior:

- If `OCLW_CRYPTO_PLUGIN` is missing, non-absolute, or not found: `RESULT=SKIP`.
- Otherwise the smoke configures the plugin and executes known vectors.

## Vectors and Expected Results

1. Valid algorithm + correct signature
- Input: `signature_alg=TEST-FNV1A32`, correct signature for (`signing_text || program_bin`)
- Expected: `Success`

2. Valid algorithm + incorrect signature
- Input: `signature_alg=TEST-FNV1A32`, wrong signature
- Expected: `OCLW_SIGNATURE_INVALID`

3. Unknown algorithm
- Input: unknown `signature_alg`
- Expected: `OCLW_SIGNATURE_INVALID`

Smoke result:

- `RESULT=PASS` only if all vectors match expected status.

## Run Examples

Reference plugin (`NOT CRYPTO`) example:

```bash
tools/crypto_provider_ref/build.sh
export OCLW_CRYPTO_PLUGIN="$(realpath tools/crypto_provider_ref/liboclw_crypto_provider_ref.so)"
export OCLW_CRYPTO_SYMBOL="oclw_kpack_verify_v1"
./tests/bin/smoke_crypto_provider_conformance
```

Real provider example:

```bash
export OCLW_CRYPTO_PLUGIN="/opt/vendor/lib/libvendor_crypto_provider.so"
export OCLW_CRYPTO_SYMBOL="oclw_kpack_verify_v1"
./tests/bin/smoke_crypto_provider_conformance
```

## Acceptance Criteria

- Plugin loads through configured symbol.
- Vector 1 returns success.
- Vectors 2 and 3 return invalid signature.
- Smoke returns `RESULT=PASS`.

Note:

- Passing this smoke validates ABI behavior and basic contract compliance.
- It does not certify cryptographic strength, certification level, or operational approval.

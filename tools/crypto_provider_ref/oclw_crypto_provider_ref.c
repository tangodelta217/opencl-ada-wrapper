#include <ctype.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

/*
 * Reference plugin for test/integration only (NOT CRYPTO).
 * Verifies TEST-FNV1A32 over: signing_text bytes || program_bin bytes.
 */

static uint32_t fnv1a32_update(uint32_t hash, const uint8_t *data, size_t len) {
  size_t i = 0;
  for (i = 0; i < len; ++i) {
    hash ^= (uint32_t)data[i];
    hash *= 0x01000193u;
  }
  return hash;
}

static void u32_to_hex8_upper(uint32_t value, char out[9]) {
  static const char hex[] = "0123456789ABCDEF";
  int i = 0;
  for (i = 0; i < 8; ++i) {
    const unsigned shift = (unsigned)(28 - (i * 4));
    out[i] = hex[(value >> shift) & 0xFu];
  }
  out[8] = '\0';
}

static int equals_hex8_case_insensitive(const char *lhs, const char *rhs) {
  size_t i = 0;
  if (lhs == NULL || rhs == NULL) {
    return 0;
  }

  if (strlen(lhs) != 8u || strlen(rhs) != 8u) {
    return 0;
  }

  for (i = 0; i < 8u; ++i) {
    if (toupper((unsigned char)lhs[i]) != toupper((unsigned char)rhs[i])) {
      return 0;
    }
  }

  return 1;
}

int oclw_kpack_verify_v1(
    const char *signature_alg,
    const char *signer_id,
    const char *signature_value,
    const uint8_t *signing_text,
    size_t signing_text_len,
    const uint8_t *program_bin,
    size_t program_bin_len) {
  uint32_t hash = 0x811C9DC5u;
  char expected_hex[9];

  (void)signer_id;

  if (signature_alg == NULL) {
    return 2;
  }

  if (strcmp(signature_alg, "TEST-FNV1A32") != 0 &&
      strcmp(signature_alg, "CMS-PKCS7-SHA256") != 0) {
    return 2;
  }

  if (signature_value == NULL) {
    return 1;
  }

  if (signing_text_len > 0u && signing_text == NULL) {
    return 1;
  }

  if (program_bin_len > 0u && program_bin == NULL) {
    return 1;
  }

  hash = fnv1a32_update(hash, signing_text, signing_text_len);
  hash = fnv1a32_update(hash, program_bin, program_bin_len);
  u32_to_hex8_upper(hash, expected_hex);

  if (equals_hex8_case_insensitive(signature_value, expected_hex)) {
    return 0;
  }

  return 1;
}

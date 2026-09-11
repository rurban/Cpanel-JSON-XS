/* utf8_range.c -- SIMD UTF-8 validation, vendored as explained in
 * utf8_range.h.  Compiled as its own object (see Makefile.PL) so the SIMD
 * bodies stay out of the parser's translation unit.
 */
#include "utf8_range.h"

#include <stdint.h>
#include <limits.h>

/* x86 needs the target attribute plus __builtin_cpu_supports(), i.e. GCC 4.9
 * or clang 4; MSVC and older compilers fall back to the scalar path.  NEON is
 * baseline on aarch64, so no dispatch is needed there. */
#if defined(__x86_64__) || defined(__i386__)
# if defined(__clang__)
#  if __clang_major__ >= 4
#   define CJSON_HAVE_X86_SIMD 1
#  endif
# elif defined(__GNUC__)
#  if __GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 9)
#   define CJSON_HAVE_X86_SIMD 1
#  endif
# endif
#endif

#if defined(__aarch64__) && (defined(__GNUC__) || defined(__clang__))
# define CJSON_HAVE_NEON 1
#endif

/* Portable scalar validation.  Returns 0 if valid, else the 1-based index of
 * the first offending character (only used as a boolean here). */


/*
 * http://www.unicode.org/versions/Unicode6.0.0/ch03.pdf - page 94
 *
 * Table 3-7. Well-Formed UTF-8 Byte Sequences
 *
 * +--------------------+------------+-------------+------------+-------------+
 * | Code Points        | First Byte | Second Byte | Third Byte | Fourth Byte |
 * +--------------------+------------+-------------+------------+-------------+
 * | U+0000..U+007F     | 00..7F     |             |            |             |
 * +--------------------+------------+-------------+------------+-------------+
 * | U+0080..U+07FF     | C2..DF     | 80..BF      |            |             |
 * +--------------------+------------+-------------+------------+-------------+
 * | U+0800..U+0FFF     | E0         | A0..BF      | 80..BF     |             |
 * +--------------------+------------+-------------+------------+-------------+
 * | U+1000..U+CFFF     | E1..EC     | 80..BF      | 80..BF     |             |
 * +--------------------+------------+-------------+------------+-------------+
 * | U+D000..U+D7FF     | ED         | 80..9F      | 80..BF     |             |
 * +--------------------+------------+-------------+------------+-------------+
 * | U+E000..U+FFFF     | EE..EF     | 80..BF      | 80..BF     |             |
 * +--------------------+------------+-------------+------------+-------------+
 * | U+10000..U+3FFFF   | F0         | 90..BF      | 80..BF     | 80..BF      |
 * +--------------------+------------+-------------+------------+-------------+
 * | U+40000..U+FFFFF   | F1..F3     | 80..BF      | 80..BF     | 80..BF      |
 * +--------------------+------------+-------------+------------+-------------+
 * | U+100000..U+10FFFF | F4         | 80..8F      | 80..BF     | 80..BF      |
 * +--------------------+------------+-------------+------------+-------------+
 */

/* Return 0 - success,  >0 - index(1 based) of first error char */
static int cjson_utf8_naive(const unsigned char *data, int len)
{
    int err_pos = 1;

    while (len) {
        int bytes;
        const unsigned char byte1 = data[0];

        /* 00..7F */
        if (byte1 <= 0x7F) {
            bytes = 1;
        /* C2..DF, 80..BF */
        } else if (len >= 2 && byte1 >= 0xC2 && byte1 <= 0xDF &&
                (signed char)data[1] <= (signed char)0xBF) {
            bytes = 2;
        } else if (len >= 3) {
            const unsigned char byte2 = data[1];

            /* Is byte2, byte3 between 0x80 ~ 0xBF */
            const int byte2_ok = (signed char)byte2 <= (signed char)0xBF;
            const int byte3_ok = (signed char)data[2] <= (signed char)0xBF;

            if (byte2_ok && byte3_ok &&
                     /* E0, A0..BF, 80..BF */
                    ((byte1 == 0xE0 && byte2 >= 0xA0) ||
                     /* E1..EC, 80..BF, 80..BF */
                     (byte1 >= 0xE1 && byte1 <= 0xEC) ||
                     /* ED, 80..9F, 80..BF */
                     (byte1 == 0xED && byte2 <= 0x9F) ||
                     /* EE..EF, 80..BF, 80..BF */
                     (byte1 >= 0xEE && byte1 <= 0xEF))) {
                bytes = 3;
            } else if (len >= 4) {
                /* Is byte4 between 0x80 ~ 0xBF */
                const int byte4_ok = (signed char)data[3] <= (signed char)0xBF;

                if (byte2_ok && byte3_ok && byte4_ok &&
                         /* F0, 90..BF, 80..BF, 80..BF */
                        ((byte1 == 0xF0 && byte2 >= 0x90) ||
                         /* F1..F3, 80..BF, 80..BF, 80..BF */
                         (byte1 >= 0xF1 && byte1 <= 0xF3) ||
                         /* F4, 80..8F, 80..BF, 80..BF */
                         (byte1 == 0xF4 && byte2 <= 0x8F))) {
                    bytes = 4;
                } else {
                    return err_pos;
                }
            } else {
                return err_pos;
            }
        } else {
            return err_pos;
        }

        len -= bytes;
        err_pos += bytes;
        data += bytes;
    }

    return 0;
}

/* ------------------------------------------------------------------ x86 --- */
#ifdef CJSON_HAVE_X86_SIMD
# include <immintrin.h>
# define CJSON_SIMD_FN(opts) __attribute__((target(opts)))
#endif

#ifdef CJSON_HAVE_X86_SIMD




/*
 * Map high nibble of "First Byte" to legal character length minus 1
 * 0x00 ~ 0xBF --> 0
 * 0xC0 ~ 0xDF --> 1
 * 0xE0 ~ 0xEF --> 2
 * 0xF0 ~ 0xFF --> 3
 */
static const int8_t cjson_sse_first_len_tbl[] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3,
};

/* Map "First Byte" to 8-th item of range table (0xC2 ~ 0xF4) */
static const int8_t cjson_sse_first_range_tbl[] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8,
};

/*
 * Range table, map range index to min and max values
 * Index 0    : 00 ~ 7F (First Byte, ascii)
 * Index 1,2,3: 80 ~ BF (Second, Third, Fourth Byte)
 * Index 4    : A0 ~ BF (Second Byte after E0)
 * Index 5    : 80 ~ 9F (Second Byte after ED)
 * Index 6    : 90 ~ BF (Second Byte after F0)
 * Index 7    : 80 ~ 8F (Second Byte after F4)
 * Index 8    : C2 ~ F4 (First Byte, non ascii)
 * Index 9~15 : illegal: i >= 127 && i <= -128
 */
static const int8_t cjson_sse_range_min_tbl[] = {
    0x00, 0x80, 0x80, 0x80, 0xA0, 0x80, 0x90, 0x80,
    0xC2, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F,
};
static const int8_t cjson_sse_range_max_tbl[] = {
    0x7F, 0xBF, 0xBF, 0xBF, 0xBF, 0x9F, 0xBF, 0x8F,
    0xF4, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
};

/*
 * Tables for fast handling of four special First Bytes(E0,ED,F0,F4), after
 * which the Second Byte are not 80~BF. It contains "range index adjustment".
 * +------------+---------------+------------------+----------------+
 * | First Byte | original range| range adjustment | adjusted range |
 * +------------+---------------+------------------+----------------+
 * | E0         | 2             | 2                | 4              |
 * +------------+---------------+------------------+----------------+
 * | ED         | 2             | 3                | 5              |
 * +------------+---------------+------------------+----------------+
 * | F0         | 3             | 3                | 6              |
 * +------------+---------------+------------------+----------------+
 * | F4         | 4             | 4                | 8              |
 * +------------+---------------+------------------+----------------+
 */
/* index1 -> E0, index14 -> ED */
static const int8_t cjson_sse_df_ee_tbl[] = {
    0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0,
};
/* index1 -> F0, index5 -> F4 */
static const int8_t cjson_sse_ef_fe_tbl[] = {
    0, 3, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

#define RET_ERR_IDX 0   /* Define 1 to return index of first error char */

/* 5x faster than naive method */
/* Return 0 - success, -1 - error, >0 - first error char(if RET_ERR_IDX = 1) */
CJSON_SIMD_FN("ssse3,sse4.1")
static int cjson_utf8_range_sse(const unsigned char *data, int len)
{
#if  RET_ERR_IDX
    int err_pos = 1;
#endif

    if (len >= 16) {
        __m128i prev_input = _mm_set1_epi8(0);
        __m128i prev_first_len = _mm_set1_epi8(0);

        /* Cached tables */
        const __m128i first_len_tbl =
            _mm_loadu_si128((const __m128i *)cjson_sse_first_len_tbl);
        const __m128i first_range_tbl =
            _mm_loadu_si128((const __m128i *)cjson_sse_first_range_tbl);
        const __m128i range_min_tbl =
            _mm_loadu_si128((const __m128i *)cjson_sse_range_min_tbl);
        const __m128i range_max_tbl =
            _mm_loadu_si128((const __m128i *)cjson_sse_range_max_tbl);
        const __m128i df_ee_tbl =
            _mm_loadu_si128((const __m128i *)cjson_sse_df_ee_tbl);
        const __m128i ef_fe_tbl =
            _mm_loadu_si128((const __m128i *)cjson_sse_ef_fe_tbl);

        __m128i error = _mm_set1_epi8(0);

        while (len >= 16) {
            /* declarations hoisted to the block top: perl built before 5.36
               passes -Werror=declaration-after-statement */
            __m128i tmp, shift1, pos, range2, minv, maxv;
            const __m128i input = _mm_loadu_si128((const __m128i *)data);

            /* high_nibbles = input >> 4 */
            const __m128i high_nibbles =
                _mm_and_si128(_mm_srli_epi16(input, 4), _mm_set1_epi8(0x0F));

            /* first_len = legal character length minus 1 */
            /* 0 for 00~7F, 1 for C0~DF, 2 for E0~EF, 3 for F0~FF */
            /* first_len = first_len_tbl[high_nibbles] */
            __m128i first_len = _mm_shuffle_epi8(first_len_tbl, high_nibbles);

            /* First Byte: set range index to 8 for bytes within 0xC0 ~ 0xFF */
            /* range = first_range_tbl[high_nibbles] */
            __m128i range = _mm_shuffle_epi8(first_range_tbl, high_nibbles);

            /* Second Byte: set range index to first_len */
            /* 0 for 00~7F, 1 for C0~DF, 2 for E0~EF, 3 for F0~FF */
            /* range |= (first_len, prev_first_len) << 1 byte */
            range = _mm_or_si128(
                    range, _mm_alignr_epi8(first_len, prev_first_len, 15));

            /* Third Byte: set range index to saturate_sub(first_len, 1) */
            /* 0 for 00~7F, 0 for C0~DF, 1 for E0~EF, 2 for F0~FF */
            /* tmp = (first_len, prev_first_len) << 2 bytes */
            tmp = _mm_alignr_epi8(first_len, prev_first_len, 14);
            /* tmp = saturate_sub(tmp, 1) */
            tmp = _mm_subs_epu8(tmp, _mm_set1_epi8(1));
            /* range |= tmp */
            range = _mm_or_si128(range, tmp);

            /* Fourth Byte: set range index to saturate_sub(first_len, 2) */
            /* 0 for 00~7F, 0 for C0~DF, 0 for E0~EF, 1 for F0~FF */
            /* tmp = (first_len, prev_first_len) << 3 bytes */
            tmp = _mm_alignr_epi8(first_len, prev_first_len, 13);
            /* tmp = saturate_sub(tmp, 2) */
            tmp = _mm_subs_epu8(tmp, _mm_set1_epi8(2));
            /* range |= tmp */
            range = _mm_or_si128(range, tmp);

            /*
             * Now we have below range indices caluclated
             * Correct cases:
             * - 8 for C0~FF
             * - 3 for 1st byte after F0~FF
             * - 2 for 1st byte after E0~EF or 2nd byte after F0~FF
             * - 1 for 1st byte after C0~DF or 2nd byte after E0~EF or
             *         3rd byte after F0~FF
             * - 0 for others
             * Error cases:
             *   9,10,11 if non ascii First Byte overlaps
             *   E.g., F1 80 C2 90 --> 8 3 10 2, where 10 indicates error
             */

            /* Adjust Second Byte range for special First Bytes(E0,ED,F0,F4) */
            /* Overlaps lead to index 9~15, which are illegal in range table */
            /* shift1 = (input, prev_input) << 1 byte */
            shift1 = _mm_alignr_epi8(input, prev_input, 15);
            pos = _mm_sub_epi8(shift1, _mm_set1_epi8(0xEF));
            /*
             * shift1:  | EF  F0 ... FE | FF  00  ... ...  DE | DF  E0 ... EE |
             * pos:     | 0   1      15 | 16  17           239| 240 241    255|
             * pos-240: | 0   0      0  | 0   0            0  | 0   1      15 |
             * pos+112: | 112 113    127|       >= 128        |     >= 128    |
             */
            tmp = _mm_subs_epu8(pos, _mm_set1_epi8(0xF0));
            range2 = _mm_shuffle_epi8(df_ee_tbl, tmp);
            tmp = _mm_adds_epu8(pos, _mm_set1_epi8(0x70));
            range2 = _mm_add_epi8(range2, _mm_shuffle_epi8(ef_fe_tbl, tmp));

            range = _mm_add_epi8(range, range2);

            /* Load min and max values per calculated range index */
            minv = _mm_shuffle_epi8(range_min_tbl, range);
            maxv = _mm_shuffle_epi8(range_max_tbl, range);

            /* Check value range */
#if RET_ERR_IDX
            error = _mm_cmplt_epi8(input, minv);
            error = _mm_or_si128(error, _mm_cmpgt_epi8(input, maxv));
            /* 5% performance drop from this conditional branch */
            if (!_mm_testz_si128(error, error))
                break;
#else
            /* error |= (input < minv) | (input > maxv) */
            tmp = _mm_or_si128(
                      _mm_cmplt_epi8(input, minv),
                      _mm_cmpgt_epi8(input, maxv)
                  );
            error = _mm_or_si128(error, tmp);
#endif

            prev_input = input;
            prev_first_len = first_len;

            data += 16;
            len -= 16;
#if RET_ERR_IDX
            err_pos += 16;
#endif
        }

#if RET_ERR_IDX
        /* Error in first 16 bytes */
        if (err_pos == 1)
            goto do_naive;
#else
        if (!_mm_testz_si128(error, error))
            return -1;
#endif

        /* Find previous token (not 80~BF) */
        {
        int32_t token4 = _mm_extract_epi32(prev_input, 3);
        const int8_t *token = (const int8_t *)&token4;
        int lookahead = 0;
        if (token[3] > (int8_t)0xBF)
            lookahead = 1;
        else if (token[2] > (int8_t)0xBF)
            lookahead = 2;
        else if (token[1] > (int8_t)0xBF)
            lookahead = 3;

        data -= lookahead;
        len += lookahead;
#if RET_ERR_IDX
        err_pos -= lookahead;
#endif
        }
    }

    /* Check remaining bytes with naive method */
#if RET_ERR_IDX
    int err_pos2;
do_naive:
    err_pos2 = cjson_utf8_naive(data, len);
    if (err_pos2)
        return err_pos + err_pos2 - 1;
    return 0;
#else
    return cjson_utf8_naive(data, len);
#endif
}
#endif /* CJSON_HAVE_X86_SIMD */
#ifdef CJSON_HAVE_X86_SIMD




/*
 * Map high nibble of "First Byte" to legal character length minus 1
 * 0x00 ~ 0xBF --> 0
 * 0xC0 ~ 0xDF --> 1
 * 0xE0 ~ 0xEF --> 2
 * 0xF0 ~ 0xFF --> 3
 */
static const int8_t cjson_avx2_first_len_tbl[] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3,
};

/* Map "First Byte" to 8-th item of range table (0xC2 ~ 0xF4) */
static const int8_t cjson_avx2_first_range_tbl[] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8,
};

/*
 * Range table, map range index to min and max values
 * Index 0    : 00 ~ 7F (First Byte, ascii)
 * Index 1,2,3: 80 ~ BF (Second, Third, Fourth Byte)
 * Index 4    : A0 ~ BF (Second Byte after E0)
 * Index 5    : 80 ~ 9F (Second Byte after ED)
 * Index 6    : 90 ~ BF (Second Byte after F0)
 * Index 7    : 80 ~ 8F (Second Byte after F4)
 * Index 8    : C2 ~ F4 (First Byte, non ascii)
 * Index 9~15 : illegal: i >= 127 && i <= -128
 */
static const int8_t cjson_avx2_range_min_tbl[] = {
    0x00, 0x80, 0x80, 0x80, 0xA0, 0x80, 0x90, 0x80,
    0xC2, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F,
    0x00, 0x80, 0x80, 0x80, 0xA0, 0x80, 0x90, 0x80,
    0xC2, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F,
};
static const int8_t cjson_avx2_range_max_tbl[] = {
    0x7F, 0xBF, 0xBF, 0xBF, 0xBF, 0x9F, 0xBF, 0x8F,
    0xF4, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
    0x7F, 0xBF, 0xBF, 0xBF, 0xBF, 0x9F, 0xBF, 0x8F,
    0xF4, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
};

/*
 * Tables for fast handling of four special First Bytes(E0,ED,F0,F4), after
 * which the Second Byte are not 80~BF. It contains "range index adjustment".
 * +------------+---------------+------------------+----------------+
 * | First Byte | original range| range adjustment | adjusted range |
 * +------------+---------------+------------------+----------------+
 * | E0         | 2             | 2                | 4              |
 * +------------+---------------+------------------+----------------+
 * | ED         | 2             | 3                | 5              |
 * +------------+---------------+------------------+----------------+
 * | F0         | 3             | 3                | 6              |
 * +------------+---------------+------------------+----------------+
 * | F4         | 4             | 4                | 8              |
 * +------------+---------------+------------------+----------------+
 */
/* index1 -> E0, index14 -> ED */
static const int8_t cjson_avx2_df_ee_tbl[] = {
    0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0,
    0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0,
};
/* index1 -> F0, index5 -> F4 */
static const int8_t cjson_avx2_ef_fe_tbl[] = {
    0, 3, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 3, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

#define RET_ERR_IDX 0   /* Define 1 to return index of first error char */

CJSON_SIMD_FN("avx2")
static inline __m256i push_last_byte_of_a_to_b(__m256i a, __m256i b) {
  return _mm256_alignr_epi8(b, _mm256_permute2x128_si256(a, b, 0x21), 15);
}

CJSON_SIMD_FN("avx2")
static inline __m256i push_last_2bytes_of_a_to_b(__m256i a, __m256i b) {
  return _mm256_alignr_epi8(b, _mm256_permute2x128_si256(a, b, 0x21), 14);
}

CJSON_SIMD_FN("avx2")
static inline __m256i push_last_3bytes_of_a_to_b(__m256i a, __m256i b) {
  return _mm256_alignr_epi8(b, _mm256_permute2x128_si256(a, b, 0x21), 13);
}

/* 5x faster than naive method */
/* Return 0 - success, -1 - error, >0 - first error char(if RET_ERR_IDX = 1) */
CJSON_SIMD_FN("avx2")
static int cjson_utf8_range_avx2(const unsigned char *data, int len)
{
#if  RET_ERR_IDX
    int err_pos = 1;
#endif

    if (len >= 32) {
        __m256i prev_input = _mm256_set1_epi8(0);
        __m256i prev_first_len = _mm256_set1_epi8(0);

        /* Cached tables */
        const __m256i first_len_tbl =
            _mm256_loadu_si256((const __m256i *)cjson_avx2_first_len_tbl);
        const __m256i first_range_tbl =
            _mm256_loadu_si256((const __m256i *)cjson_avx2_first_range_tbl);
        const __m256i range_min_tbl =
            _mm256_loadu_si256((const __m256i *)cjson_avx2_range_min_tbl);
        const __m256i range_max_tbl =
            _mm256_loadu_si256((const __m256i *)cjson_avx2_range_max_tbl);
        const __m256i df_ee_tbl =
            _mm256_loadu_si256((const __m256i *)cjson_avx2_df_ee_tbl);
        const __m256i ef_fe_tbl =
            _mm256_loadu_si256((const __m256i *)cjson_avx2_ef_fe_tbl);

#if !RET_ERR_IDX
        __m256i error1 = _mm256_set1_epi8(0);
        __m256i error2 = _mm256_set1_epi8(0);
        __m256i error;
#endif

        while (len >= 32) {
            /* declarations hoisted to the block top, see the SSE version */
            __m256i tmp1, tmp2, shift1, pos, range2, minv, maxv;
            const __m256i input = _mm256_loadu_si256((const __m256i *)data);

            /* high_nibbles = input >> 4 */
            const __m256i high_nibbles =
                _mm256_and_si256(_mm256_srli_epi16(input, 4), _mm256_set1_epi8(0x0F));

            /* first_len = legal character length minus 1 */
            /* 0 for 00~7F, 1 for C0~DF, 2 for E0~EF, 3 for F0~FF */
            /* first_len = first_len_tbl[high_nibbles] */
            __m256i first_len = _mm256_shuffle_epi8(first_len_tbl, high_nibbles);

            /* First Byte: set range index to 8 for bytes within 0xC0 ~ 0xFF */
            /* range = first_range_tbl[high_nibbles] */
            __m256i range = _mm256_shuffle_epi8(first_range_tbl, high_nibbles);

            /* Second Byte: set range index to first_len */
            /* 0 for 00~7F, 1 for C0~DF, 2 for E0~EF, 3 for F0~FF */
            /* range |= (first_len, prev_first_len) << 1 byte */
            range = _mm256_or_si256(
                    range, push_last_byte_of_a_to_b(prev_first_len, first_len));

            /* Third Byte: set range index to saturate_sub(first_len, 1) */
            /* 0 for 00~7F, 0 for C0~DF, 1 for E0~EF, 2 for F0~FF */

            /* tmp1 = (first_len, prev_first_len) << 2 bytes */
            tmp1 = push_last_2bytes_of_a_to_b(prev_first_len, first_len);
            /* tmp2 = saturate_sub(tmp1, 1) */
            tmp2 = _mm256_subs_epu8(tmp1, _mm256_set1_epi8(1));

            /* range |= tmp2 */
            range = _mm256_or_si256(range, tmp2);

            /* Fourth Byte: set range index to saturate_sub(first_len, 2) */
            /* 0 for 00~7F, 0 for C0~DF, 0 for E0~EF, 1 for F0~FF */
            /* tmp1 = (first_len, prev_first_len) << 3 bytes */
            tmp1 = push_last_3bytes_of_a_to_b(prev_first_len, first_len);
            /* tmp2 = saturate_sub(tmp1, 2) */
            tmp2 = _mm256_subs_epu8(tmp1, _mm256_set1_epi8(2));
            /* range |= tmp2 */
            range = _mm256_or_si256(range, tmp2);

            /*
             * Now we have below range indices caluclated
             * Correct cases:
             * - 8 for C0~FF
             * - 3 for 1st byte after F0~FF
             * - 2 for 1st byte after E0~EF or 2nd byte after F0~FF
             * - 1 for 1st byte after C0~DF or 2nd byte after E0~EF or
             *         3rd byte after F0~FF
             * - 0 for others
             * Error cases:
             *   9,10,11 if non ascii First Byte overlaps
             *   E.g., F1 80 C2 90 --> 8 3 10 2, where 10 indicates error
             */

            /* Adjust Second Byte range for special First Bytes(E0,ED,F0,F4) */
            /* Overlaps lead to index 9~15, which are illegal in range table */
            /* shift1 = (input, prev_input) << 1 byte */
            shift1 = push_last_byte_of_a_to_b(prev_input, input);
            pos = _mm256_sub_epi8(shift1, _mm256_set1_epi8(0xEF));
            /*
             * shift1:  | EF  F0 ... FE | FF  00  ... ...  DE | DF  E0 ... EE |
             * pos:     | 0   1      15 | 16  17           239| 240 241    255|
             * pos-240: | 0   0      0  | 0   0            0  | 0   1      15 |
             * pos+112: | 112 113    127|       >= 128        |     >= 128    |
             */
            tmp1 = _mm256_subs_epu8(pos, _mm256_set1_epi8(240));
            range2 = _mm256_shuffle_epi8(df_ee_tbl, tmp1);
            tmp2 = _mm256_adds_epu8(pos, _mm256_set1_epi8(112));
            range2 = _mm256_add_epi8(range2, _mm256_shuffle_epi8(ef_fe_tbl, tmp2));

            range = _mm256_add_epi8(range, range2);

            /* Load min and max values per calculated range index */
            minv = _mm256_shuffle_epi8(range_min_tbl, range);
            maxv = _mm256_shuffle_epi8(range_max_tbl, range);

            /* Check value range */
#if RET_ERR_IDX
            __m256i error = _mm256_cmpgt_epi8(minv, input);
            error = _mm256_or_si256(error, _mm256_cmpgt_epi8(input, maxv));
            /* 5% performance drop from this conditional branch */
            if (!_mm256_testz_si256(error, error))
                break;
#else
            error1 = _mm256_or_si256(error1, _mm256_cmpgt_epi8(minv, input));
            error2 = _mm256_or_si256(error2, _mm256_cmpgt_epi8(input, maxv));
#endif

            prev_input = input;
            prev_first_len = first_len;

            data += 32;
            len -= 32;
#if RET_ERR_IDX
            err_pos += 32;
#endif
        }

#if RET_ERR_IDX
        /* Error in first 16 bytes */
        if (err_pos == 1)
            goto do_naive;
#else
        error = _mm256_or_si256(error1, error2);
        if (!_mm256_testz_si256(error, error))
            return -1;
#endif

        /* Find previous token (not 80~BF) */
        {
        int32_t token4 = _mm256_extract_epi32(prev_input, 7);
        const int8_t *token = (const int8_t *)&token4;
        int lookahead = 0;
        if (token[3] > (int8_t)0xBF)
            lookahead = 1;
        else if (token[2] > (int8_t)0xBF)
            lookahead = 2;
        else if (token[1] > (int8_t)0xBF)
            lookahead = 3;

        data -= lookahead;
        len += lookahead;
#if RET_ERR_IDX
        err_pos -= lookahead;
#endif
        }
    }

    /* Check remaining bytes with naive method */
#if RET_ERR_IDX
    int err_pos2;
do_naive:
    err_pos2 = cjson_utf8_naive(data, len);
    if (err_pos2)
        return err_pos + err_pos2 - 1;
    return 0;
#else
    return cjson_utf8_naive(data, len);
#endif
}
#endif /* CJSON_HAVE_X86_SIMD */

/* ------------------------------------------------------------------ ARM --- */
#ifdef CJSON_HAVE_NEON
# include <arm_neon.h>
# define CJSON_SIMD_FN(opts)
#endif

#ifdef CJSON_HAVE_NEON




/*
 * Map high nibble of "First Byte" to legal character length minus 1
 * 0x00 ~ 0xBF --> 0
 * 0xC0 ~ 0xDF --> 1
 * 0xE0 ~ 0xEF --> 2
 * 0xF0 ~ 0xFF --> 3
 */
static const uint8_t cjson_neon_first_len_tbl[] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3,
};

/* Map "First Byte" to 8-th item of range table (0xC2 ~ 0xF4) */
static const uint8_t cjson_neon_first_range_tbl[] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8,
};

/*
 * Range table, map range index to min and max values
 * Index 0    : 00 ~ 7F (First Byte, ascii)
 * Index 1,2,3: 80 ~ BF (Second, Third, Fourth Byte)
 * Index 4    : A0 ~ BF (Second Byte after E0)
 * Index 5    : 80 ~ 9F (Second Byte after ED)
 * Index 6    : 90 ~ BF (Second Byte after F0)
 * Index 7    : 80 ~ 8F (Second Byte after F4)
 * Index 8    : C2 ~ F4 (First Byte, non ascii)
 * Index 9~15 : illegal: u >= 255 && u <= 0
 */
static const uint8_t cjson_neon_range_min_tbl[] = {
    0x00, 0x80, 0x80, 0x80, 0xA0, 0x80, 0x90, 0x80,
    0xC2, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
};
static const uint8_t cjson_neon_range_max_tbl[] = {
    0x7F, 0xBF, 0xBF, 0xBF, 0xBF, 0x9F, 0xBF, 0x8F,
    0xF4, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};

/*
 * This table is for fast handling four special First Bytes(E0,ED,F0,F4), after
 * which the Second Byte are not 80~BF. It contains "range index adjustment".
 * - The idea is to minus byte with E0, use the result(0~31) as the index to
 *   lookup the "range index adjustment". Then add the adjustment to original
 *   range index to get the correct range.
 * - Range index adjustment
 *   +------------+---------------+------------------+----------------+
 *   | First Byte | original range| range adjustment | adjusted range |
 *   +------------+---------------+------------------+----------------+
 *   | E0         | 2             | 2                | 4              |
 *   +------------+---------------+------------------+----------------+
 *   | ED         | 2             | 3                | 5              |
 *   +------------+---------------+------------------+----------------+
 *   | F0         | 3             | 3                | 6              |
 *   +------------+---------------+------------------+----------------+
 *   | F4         | 4             | 4                | 8              |
 *   +------------+---------------+------------------+----------------+
 * - Below is a uint8x16x2 table, data is interleaved in NEON register. So I'm
 *   putting it vertically. 1st column is for E0~EF, 2nd column for F0~FF.
 */
static const uint8_t cjson_neon_range_adjust_tbl[] = {
    /* index -> 0~15  16~31 <- index */
    /*  E0 -> */ 2,     3, /* <- F0  */
                 0,     0,
                 0,     0,
                 0,     0,
                 0,     4, /* <- F4  */
                 0,     0,
                 0,     0,
                 0,     0,
                 0,     0,
                 0,     0,
                 0,     0,
                 0,     0,
                 0,     0,
    /*  ED -> */ 3,     0,
                 0,     0,
                 0,     0,
};

/* 2x ~ 4x faster than naive method */
/* Return 0 on success, -1 on error */
static int cjson_utf8_range_neon(const unsigned char *data, int len)
{
    if (len >= 16) {
        uint8x16_t prev_input = vdupq_n_u8(0);
        uint8x16_t prev_first_len = vdupq_n_u8(0);

        /* Cached tables */
        const uint8x16_t first_len_tbl = vld1q_u8(cjson_neon_first_len_tbl);
        const uint8x16_t first_range_tbl = vld1q_u8(cjson_neon_first_range_tbl);
        const uint8x16_t range_min_tbl = vld1q_u8(cjson_neon_range_min_tbl);
        const uint8x16_t range_max_tbl = vld1q_u8(cjson_neon_range_max_tbl);
        const uint8x16x2_t range_adjust_tbl = vld2q_u8(cjson_neon_range_adjust_tbl);

        /* Cached values */
        const uint8x16_t const_1 = vdupq_n_u8(1);
        const uint8x16_t const_2 = vdupq_n_u8(2);
        const uint8x16_t const_e0 = vdupq_n_u8(0xE0);

        /* We use two error registers to remove a dependency. */
        uint8x16_t error1 = vdupq_n_u8(0);
        uint8x16_t error2 = vdupq_n_u8(0);

        while (len >= 16) {
            const uint8x16_t input = vld1q_u8(data);

            /* high_nibbles = input >> 4 */
            const uint8x16_t high_nibbles = vshrq_n_u8(input, 4);

            /* first_len = legal character length minus 1 */
            /* 0 for 00~7F, 1 for C0~DF, 2 for E0~EF, 3 for F0~FF */
            /* first_len = first_len_tbl[high_nibbles] */
            const uint8x16_t first_len =
                vqtbl1q_u8(first_len_tbl, high_nibbles);

            /* First Byte: set range index to 8 for bytes within 0xC0 ~ 0xFF */
            /* range = first_range_tbl[high_nibbles] */
            uint8x16_t range = vqtbl1q_u8(first_range_tbl, high_nibbles);

            /* Second Byte: set range index to first_len */
            /* 0 for 00~7F, 1 for C0~DF, 2 for E0~EF, 3 for F0~FF */
            /* range |= (first_len, prev_first_len) << 1 byte */
            range =
                vorrq_u8(range, vextq_u8(prev_first_len, first_len, 15));

            /* Third Byte: set range index to saturate_sub(first_len, 1) */
            /* 0 for 00~7F, 0 for C0~DF, 1 for E0~EF, 2 for F0~FF */
            uint8x16_t tmp1, tmp2;
            /* tmp1 = (first_len, prev_first_len) << 2 bytes */
            tmp1 = vextq_u8(prev_first_len, first_len, 14);
            /* tmp1 = saturate_sub(tmp1, 1) */
            tmp1 = vqsubq_u8(tmp1, const_1);
            /* range |= tmp1 */
            range = vorrq_u8(range, tmp1);

            /* Fourth Byte: set range index to saturate_sub(first_len, 2) */
            /* 0 for 00~7F, 0 for C0~DF, 0 for E0~EF, 1 for F0~FF */
            /* tmp2 = (first_len, prev_first_len) << 3 bytes */
            tmp2 = vextq_u8(prev_first_len, first_len, 13);
            /* tmp2 = saturate_sub(tmp2, 2) */
            tmp2 = vqsubq_u8(tmp2, const_2);
            /* range |= tmp2 */
            range = vorrq_u8(range, tmp2);

            /*
             * Now we have below range indices caluclated
             * Correct cases:
             * - 8 for C0~FF
             * - 3 for 1st byte after F0~FF
             * - 2 for 1st byte after E0~EF or 2nd byte after F0~FF
             * - 1 for 1st byte after C0~DF or 2nd byte after E0~EF or
             *         3rd byte after F0~FF
             * - 0 for others
             * Error cases:
             *   9,10,11 if non ascii First Byte overlaps
             *   E.g., F1 80 C2 90 --> 8 3 10 2, where 10 indicates error
             */

            /* Adjust Second Byte range for special First Bytes(E0,ED,F0,F4) */
            /* See cjson_neon_range_adjust_tbl[] definition for details */
            /* Overlaps lead to index 9~15, which are illegal in range table */
            uint8x16_t shift1 = vextq_u8(prev_input, input, 15);
            uint8x16_t pos = vsubq_u8(shift1, const_e0);
            range = vaddq_u8(range, vqtbl2q_u8(range_adjust_tbl, pos));

            /* Load min and max values per calculated range index */
            uint8x16_t minv = vqtbl1q_u8(range_min_tbl, range);
            uint8x16_t maxv = vqtbl1q_u8(range_max_tbl, range);

            /* Check value range */
            error1 = vorrq_u8(error1, vcltq_u8(input, minv));
            error2 = vorrq_u8(error2, vcgtq_u8(input, maxv));

            prev_input = input;
            prev_first_len = first_len;

            data += 16;
            len -= 16;
        }
        /* Merge our error counters together */
        error1 = vorrq_u8(error1, error2);

        /* Delay error check till loop ends */
        if (vmaxvq_u8(error1))
            return -1;

        /* Find previous token (not 80~BF) */
        uint32_t token4;
        vst1q_lane_u32(&token4, vreinterpretq_u32_u8(prev_input), 3);

        const int8_t *token = (const int8_t *)&token4;
        int lookahead = 0;
        if (token[3] > (int8_t)0xBF)
            lookahead = 1;
        else if (token[2] > (int8_t)0xBF)
            lookahead = 2;
        else if (token[1] > (int8_t)0xBF)
            lookahead = 3;

        data -= lookahead;
        len += lookahead;
    }

    /* Check remaining bytes with naive method */
    return cjson_utf8_naive(data, len);
}
#endif /* CJSON_HAVE_NEON */

/* ------------------------------------------------------------- dispatch --- */
/* Which SIMD backend this CPU has; set from a constructor so the hot path
 * never pays for a cpuid.  Stays 0 (scalar) if no constructor ran. */
#if defined(CJSON_HAVE_X86_SIMD)
static int cjson_utf8_backend = 0; /* 0 = scalar, 1 = sse4.1, 2 = avx2 */

__attribute__((constructor))
static void cjson_utf8_backend_init (void)
{
  __builtin_cpu_init ();
  if (__builtin_cpu_supports ("avx2"))
    cjson_utf8_backend = 2;
  else if (__builtin_cpu_supports ("sse4.1"))
    cjson_utf8_backend = 1;
}
#endif

/* Offset of the first byte >= 0x80, or len if the input is pure ascii.  Lets a
 * pure-ascii document -- the common case, and one that never reaches the
 * decoder -- cost a movemask pass instead of the whole range algorithm. */
#ifdef CJSON_HAVE_X86_SIMD
CJSON_SIMD_FN("avx2")
static size_t
cjson_first_high_avx2 (const unsigned char *d, size_t n)
{
  size_t i = 0;
  for (; i + 32 <= n; i += 32)
    {
      __m256i v = _mm256_loadu_si256 ((const __m256i *)(d + i));
      unsigned m = (unsigned)_mm256_movemask_epi8 (v);
      if (m)
        return i + (size_t)__builtin_ctz (m);
    }
  for (; i < n; i++)
    if (d[i] >= 0x80)
      return i;
  return n;
}

CJSON_SIMD_FN("sse2")
static size_t
cjson_first_high_sse2 (const unsigned char *d, size_t n)
{
  size_t i = 0;
  for (; i + 16 <= n; i += 16)
    {
      __m128i v = _mm_loadu_si128 ((const __m128i *)(d + i));
      unsigned m = (unsigned)_mm_movemask_epi8 (v);
      if (m)
        return i + (size_t)__builtin_ctz (m);
    }
  for (; i < n; i++)
    if (d[i] >= 0x80)
      return i;
  return n;
}
#endif /* CJSON_HAVE_X86_SIMD */

static size_t
cjson_first_high_scalar (const unsigned char *d, size_t n)
{
  size_t i = 0;
  for (; i < n; i++)
    if (d[i] >= 0x80)
      return i;
  return n;
}

static size_t
cjson_utf8_first_high (const unsigned char *data, size_t len)
{
#if defined(CJSON_HAVE_X86_SIMD)
  if (cjson_utf8_backend == 2)
    return cjson_first_high_avx2 (data, len);
  if (cjson_utf8_backend == 1)
    return cjson_first_high_sse2 (data, len);
#endif
  return cjson_first_high_scalar (data, len);
}

int
cjson_utf8_validate (const unsigned char *data, size_t len)
{
  int n;
  size_t off;

  /* >2GB of input: don't bother, let the caller use its safe path */
  if (len > (size_t)INT_MAX)
    return 0;

  /* skip a pure-ascii prefix: those bytes are valid by definition and each is
   * a complete character, so the range algorithm may start right after it */
  off = cjson_utf8_first_high (data, len);
  if (off == len)
    return 1;
  data += off;
  len -= off;

  n = (int)len;
  if (n < 16)
    return cjson_utf8_naive (data, n) == 0;
#if defined(CJSON_HAVE_X86_SIMD)
  if (cjson_utf8_backend == 2)
    return cjson_utf8_range_avx2 (data, n) == 0;
  if (cjson_utf8_backend == 1)
    return cjson_utf8_range_sse (data, n) == 0;
  return cjson_utf8_naive (data, n) == 0;
#elif defined(CJSON_HAVE_NEON)
  return cjson_utf8_range_neon (data, n) == 0;
#else
  return cjson_utf8_naive (data, n) == 0;
#endif
}

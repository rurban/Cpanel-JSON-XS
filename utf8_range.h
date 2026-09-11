/* utf8_range.h -- fast SIMD UTF-8 validation, the "range" algorithm.
 *
 * Vendored from https://github.com/cyb70289/utf8 (MIT, (c) 2018 Zhang Boyang),
 * the same code protobuf ships in third_party/utf8_range and scylladb uses.
 * See Cpanel::JSON::XS GH #213.  Implemented in utf8_range.c; only identifiers,
 * linkage and the platform guards differ from upstream, so each backend stays
 * diffable against it.  They live in their own translation unit so they cannot
 * perturb the inlining of the parser's hot loops.
 *
 * Upstream license:
 *   MIT License, Copyright (c) 2018 Zhang Boyang
 *   Permission is hereby granted, free of charge, to any person obtaining a
 *   copy of this software and associated documentation files (the "Software"),
 *   to deal in the Software without restriction, including without limitation
 *   the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *   and/or sell copies of the Software, and to permit persons to whom the
 *   Software is furnished to do so, subject to the following conditions:
 *   The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.  THE SOFTWARE IS
 *   PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
 *
 * cjson_utf8_validate() returns 1 iff [data, data+len) is strictly well-formed
 * UTF-8 (RFC 3629): no overlong forms, no surrogates, nothing above U+10FFFF,
 * nothing truncated.  That is exactly the set perl's utf8n_to_uvchr() accepts
 * with UTF8_DISALLOW_SURROGATE and UTF8_DISALLOW_SUPER, i.e. what
 * Cpanel::JSON::XS decode_utf8() accepts in non-relaxed mode -- so callers may
 * skip their per-character checks once this returns 1.  When it returns 0 the
 * caller must use its own safe path; relaxed mode still accepts a superset.
 *
 * Backends: AVX2 / SSE4.1 (x86, runtime dispatched via a constructor), NEON
 * (aarch64), and a portable scalar fallback.  No special compiler switch
 * needed; compilers without the target attribute use the scalar path.
 */
#ifndef CJSON_UTF8_RANGE_H
#define CJSON_UTF8_RANGE_H

#include <stddef.h>

int cjson_utf8_validate (const unsigned char *data, size_t len);

#endif /* CJSON_UTF8_RANGE_H */

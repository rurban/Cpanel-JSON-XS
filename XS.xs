#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "assert.h"
#include "string.h"
#include "stdlib.h"

#define F_ASCII        0x00000001UL
#define F_UTF8         0x00000002UL
#define F_INDENT       0x00000004UL
#define F_CANONICAL    0x00000008UL
#define F_SPACE_BEFORE 0x00000010UL
#define F_SPACE_AFTER  0x00000020UL
#define F_ALLOW_NONREF 0x00000080UL
#define F_SHRINK       0x00000100UL
#define F_MAXDEPTH     0xf8000000UL
#define S_MAXDEPTH     27

#define DEC_DEPTH(flags) (1UL << ((flags & F_MAXDEPTH) >> S_MAXDEPTH))

// F_SELFCONVERT? <=> to_json/toJson
// F_BLESSED?     <=> { $__class__$ => }

#define F_PRETTY    F_INDENT | F_SPACE_BEFORE | F_SPACE_AFTER
#define F_DEFAULT   (9UL << S_MAXDEPTH)

#define INIT_SIZE   32 // initial scalar size to be allocated
#define INDENT_STEP 3  // spaces per indentation level

#define UTF8_MAX_LEN      11 // for perls UTF-X: max. number of octets per character
#define SHORT_STRING_LEN 512 // special-case strings of up to this size

#define SB do {
#define SE } while (0)

static HV *json_stash; // JSON::XS::

/////////////////////////////////////////////////////////////////////////////
// utility functions

static UV *
SvJSON (SV *sv)
{
  if (!(SvROK (sv) && SvOBJECT (SvRV (sv)) && SvSTASH (SvRV (sv)) == json_stash))
    croak ("object is not of type JSON::XS");

  return &SvUVX (SvRV (sv));
}

static void
shrink (SV *sv)
{
  sv_utf8_downgrade (sv, 1);
  if (SvLEN (sv) > SvCUR (sv) + 1)
    {
#ifdef SvPV_shrink_to_cur
      SvPV_shrink_to_cur (sv);
#elif defined (SvPV_renew)
      SvPV_renew (sv, SvCUR (sv) + 1);
#endif
    }
}

// decode an utf-8 character and return it, or (UV)-1 in
// case of an error.
// we special-case "safe" characters from U+80 .. U+7FF,
// but use the very good perl function to parse anything else.
// note that we never call this function for a ascii codepoints
static UV
decode_utf8 (unsigned char *s, STRLEN len, STRLEN *clen)
{
  if (s[0] > 0xdf || s[0] < 0xc2)
    return utf8n_to_uvuni (s, len, clen, UTF8_CHECK_ONLY);
  else if (len > 1 && s[1] >= 0x80 && s[1] <= 0xbf)
    {
      *clen = 2;
      return ((s[0] & 0x1f) << 6) | (s[1] & 0x3f);
    }
  else
    {
      *clen = (STRLEN)-1;
      return (UV)-1;
    }
}

/////////////////////////////////////////////////////////////////////////////
// encoder

// structure used for encoding JSON
typedef struct
{
  char *cur;  // SvPVX (sv) + current output position
  char *end;  // SvEND (sv)
  SV *sv;     // result scalar
  U32 flags;   // F_*
  U32 indent; // indentation level
  U32 maxdepth; // max. indentation/recursion level
} enc_t;

static void
need (enc_t *enc, STRLEN len)
{
  if (enc->cur + len >= enc->end)
    {
      STRLEN cur = enc->cur - SvPVX (enc->sv);
      SvGROW (enc->sv, cur + len + 1);
      enc->cur = SvPVX (enc->sv) + cur;
      enc->end = SvPVX (enc->sv) + SvLEN (enc->sv);
    }
}

static void
encode_ch (enc_t *enc, char ch)
{
  need (enc, 1);
  *enc->cur++ = ch;
}

static void
encode_str (enc_t *enc, char *str, STRLEN len, int is_utf8)
{
  char *end = str + len;

  need (enc, len);

  while (str < end)
    {
      unsigned char ch = *(unsigned char *)str;

      if (ch >= 0x20 && ch < 0x80) // most common case
        {
          if (ch == '"') // but with slow exceptions
            {
              need (enc, len += 1);
              *enc->cur++ = '\\';
              *enc->cur++ = '"';
            }
          else if (ch == '\\')
            {
              need (enc, len += 1);
              *enc->cur++ = '\\';
              *enc->cur++ = '\\';
            }
          else
            *enc->cur++ = ch;

          ++str;
        }
      else
        {
          switch (ch)
            {
              case '\010': need (enc, len += 1); *enc->cur++ = '\\'; *enc->cur++ = 'b'; ++str; break;
              case '\011': need (enc, len += 1); *enc->cur++ = '\\'; *enc->cur++ = 't'; ++str; break;
              case '\012': need (enc, len += 1); *enc->cur++ = '\\'; *enc->cur++ = 'n'; ++str; break;
              case '\014': need (enc, len += 1); *enc->cur++ = '\\'; *enc->cur++ = 'f'; ++str; break;
              case '\015': need (enc, len += 1); *enc->cur++ = '\\'; *enc->cur++ = 'r'; ++str; break;

              default:
                {
                  STRLEN clen;
                  UV uch;

                  if (is_utf8)
                    {
                      //uch = utf8n_to_uvuni (str, end - str, &clen, UTF8_CHECK_ONLY);
                      uch = decode_utf8 (str, end - str, &clen);
                      if (clen == (STRLEN)-1)
                        croak ("malformed or illegal unicode character in string [%.11s], cannot convert to JSON", str);
                    }
                  else
                    {
                      uch = ch;
                      clen = 1;
                    }

                  if (uch > 0x10FFFFUL)
                    croak ("out of range codepoint (0x%lx) encountered, unrepresentable in JSON", (unsigned long)uch);

                  if (uch < 0x80 || enc->flags & F_ASCII)
                    {
                      if (uch > 0xFFFFUL)
                        {
                          need (enc, len += 11);
                          sprintf (enc->cur, "\\u%04x\\u%04x",
                                   (int)((uch - 0x10000) / 0x400 + 0xD800),
                                   (int)((uch - 0x10000) % 0x400 + 0xDC00));
                          enc->cur += 12;
                        }
                      else
                        {
                          static char hexdigit [16] = "0123456789abcdef";
                          need (enc, len += 5);
                          *enc->cur++ = '\\';
                          *enc->cur++ = 'u';
                          *enc->cur++ = hexdigit [ uch >> 12      ];
                          *enc->cur++ = hexdigit [(uch >>  8) & 15];
                          *enc->cur++ = hexdigit [(uch >>  4) & 15];
                          *enc->cur++ = hexdigit [(uch >>  0) & 15];
                        }

                      str += clen;
                    }
                  else if (is_utf8)
                    {
                      need (enc, len += clen);
                      do
                        {
                          *enc->cur++ = *str++;
                        }
                      while (--clen);
                    }
                  else
                    {
                      need (enc, len += UTF8_MAX_LEN - 1); // never more than 11 bytes needed
                      enc->cur = uvuni_to_utf8_flags (enc->cur, uch, 0);
                      ++str;
                    }
                }
            }
        }

      --len;
    }
}

static void
encode_indent (enc_t *enc)
{
  if (enc->flags & F_INDENT)
    {
      int spaces = enc->indent * INDENT_STEP;

      need (enc, spaces);
      memset (enc->cur, ' ', spaces);
      enc->cur += spaces;
    }
}

static void
encode_space (enc_t *enc)
{
  need (enc, 1);
  encode_ch (enc, ' ');
}

static void
encode_nl (enc_t *enc)
{
  if (enc->flags & F_INDENT)
    {
      need (enc, 1);
      encode_ch (enc, '\n');
    }
}

static void
encode_comma (enc_t *enc)
{
  encode_ch (enc, ',');

  if (enc->flags & F_INDENT)
    encode_nl (enc);
  else if (enc->flags & F_SPACE_AFTER)
    encode_space (enc);
}

static void encode_sv (enc_t *enc, SV *sv);

static void
encode_av (enc_t *enc, AV *av)
{
  int i, len = av_len (av);

  if (enc->indent >= enc->maxdepth)
    croak ("data structure too deep (hit recursion limit)");

  encode_ch (enc, '['); encode_nl (enc);
  ++enc->indent;

  for (i = 0; i <= len; ++i)
    {
      encode_indent (enc);
      encode_sv (enc, *av_fetch (av, i, 0));

      if (i < len)
        encode_comma (enc);
    }

  encode_nl (enc);

  --enc->indent;
  encode_indent (enc); encode_ch (enc, ']');
}

static void
encode_he (enc_t *enc, HE *he)
{
  encode_ch (enc, '"');

  if (HeKLEN (he) == HEf_SVKEY)
    {
      SV *sv = HeSVKEY (he);
      STRLEN len;
      char *str;
      
      SvGETMAGIC (sv);
      str = SvPV (sv, len);

      encode_str (enc, str, len, SvUTF8 (sv));
    }
  else
    encode_str (enc, HeKEY (he), HeKLEN (he), HeKUTF8 (he));

  encode_ch (enc, '"');

  if (enc->flags & F_SPACE_BEFORE) encode_space (enc);
  encode_ch (enc, ':');
  if (enc->flags & F_SPACE_AFTER ) encode_space (enc);
  encode_sv (enc, HeVAL (he));
}

// compare hash entries, used when all keys are bytestrings
static int
he_cmp_fast (const void *a_, const void *b_)
{
  int cmp;

  HE *a = *(HE **)a_;
  HE *b = *(HE **)b_;

  STRLEN la = HeKLEN (a);
  STRLEN lb = HeKLEN (b);

  if (!(cmp = memcmp (HeKEY (a), HeKEY (b), la < lb ? la : lb)))
    cmp = la - lb;

  return cmp;
}

// compare hash entries, used when some keys are sv's or utf-x
static int
he_cmp_slow (const void *a, const void *b)
{
  return sv_cmp (HeSVKEY_force (*(HE **)a), HeSVKEY_force (*(HE **)b));
}

static void
encode_hv (enc_t *enc, HV *hv)
{
  int count, i;

  if (enc->indent >= enc->maxdepth)
    croak ("data structure too deep (hit recursion limit)");

  encode_ch (enc, '{'); encode_nl (enc); ++enc->indent;

  if ((count = hv_iterinit (hv)))
    {
      // for canonical output we have to sort by keys first
      // actually, this is mostly due to the stupid so-called
      // security workaround added somewhere in 5.8.x.
      // that randomises hash orderings
      if (enc->flags & F_CANONICAL)
        {
          HE *he, *hes [count]; // if your compiler dies here, you need to enable C99 mode
          int fast = 1;

          i = 0;
          while ((he = hv_iternext (hv)))
            {
              hes [i++] = he;
              if (HeKLEN (he) < 0 || HeKUTF8 (he))
                fast = 0;
            }

          assert (i == count);

          if (fast)
            qsort (hes, count, sizeof (HE *), he_cmp_fast);
          else
            {
              // hack to forcefully disable "use bytes"
              COP cop = *PL_curcop;
              cop.op_private = 0;

              ENTER;
              SAVETMPS;

              SAVEVPTR (PL_curcop);
              PL_curcop = &cop;

              qsort (hes, count, sizeof (HE *), he_cmp_slow);

              FREETMPS;
              LEAVE;
            }

          for (i = 0; i < count; ++i)
            {
              encode_indent (enc);
              encode_he (enc, hes [i]);

              if (i < count - 1)
                encode_comma (enc);
            }

          encode_nl (enc);
        }
      else
        {
          SV *sv;
          HE *he = hv_iternext (hv);

          for (;;)
            {
              encode_indent (enc);
              encode_he (enc, he);

              if (!(he = hv_iternext (hv)))
                break;

              encode_comma (enc);
            }

          encode_nl (enc);
        }
    }

  --enc->indent; encode_indent (enc); encode_ch (enc, '}');
}

// encode objects, arrays and special \0=false and \1=true values.
static void
encode_rv (enc_t *enc, SV *sv)
{
  SvGETMAGIC (sv);

  svtype svt = SvTYPE (sv);

  if (svt == SVt_PVHV)
    encode_hv (enc, (HV *)sv);
  else if (svt == SVt_PVAV)
    encode_av (enc, (AV *)sv);
  else if (svt < SVt_PVAV)
    {
      if (SvNIOK (sv) && SvIV (sv) == 0)
        encode_str (enc, "false", 5, 0);
      else if (SvNIOK (sv) && SvIV (sv) == 1)
        encode_str (enc, "true", 4, 0);
      else
        croak ("cannot encode reference to scalar '%s' unless the scalar is 0 or 1",
               SvPV_nolen (sv_2mortal (newRV_inc (sv))));
    }
  else
    croak ("encountered %s, but JSON can only represent references to arrays or hashes",
           SvPV_nolen (sv_2mortal (newRV_inc (sv))));
}

static void
encode_sv (enc_t *enc, SV *sv)
{
  SvGETMAGIC (sv);

  if (SvPOKp (sv))
    {
      STRLEN len;
      char *str = SvPV (sv, len);
      encode_ch (enc, '"');
      encode_str (enc, str, len, SvUTF8 (sv));
      encode_ch (enc, '"');
    }
  else if (SvNOKp (sv))
    {
      need (enc, NV_DIG + 32);
      Gconvert (SvNVX (sv), NV_DIG, 0, enc->cur);
      enc->cur += strlen (enc->cur);
    }
  else if (SvIOKp (sv))
    {
      need (enc, 64);
      enc->cur += 
         SvIsUV(sv)
            ? snprintf (enc->cur, 64, "%"UVuf, (UV)SvUVX (sv))
            : snprintf (enc->cur, 64, "%"IVdf, (IV)SvIVX (sv));
    }
  else if (SvROK (sv))
    encode_rv (enc, SvRV (sv));
  else if (!SvOK (sv))
    encode_str (enc, "null", 4, 0);
  else
    croak ("encountered perl type (%s,0x%x) that JSON cannot handle, you might want to report this",
           SvPV_nolen (sv), SvFLAGS (sv));
}

static SV *
encode_json (SV *scalar, U32 flags)
{
  if (!(flags & F_ALLOW_NONREF) && !SvROK (scalar))
    croak ("hash- or arrayref expected (not a simple scalar, use allow_nonref to allow this)");

  enc_t enc;
  enc.flags     = flags;
  enc.sv        = sv_2mortal (NEWSV (0, INIT_SIZE));
  enc.cur       = SvPVX (enc.sv);
  enc.end       = SvEND (enc.sv);
  enc.indent    = 0;
  enc.maxdepth  = DEC_DEPTH (flags);

  SvPOK_only (enc.sv);
  encode_sv (&enc, scalar);

  if (!(flags & (F_ASCII | F_UTF8)))
    SvUTF8_on (enc.sv);

  SvCUR_set (enc.sv, enc.cur - SvPVX (enc.sv));

  if (enc.flags & F_SHRINK)
    shrink (enc.sv);

  return enc.sv;
}

/////////////////////////////////////////////////////////////////////////////
// decoder

// structure used for decoding JSON
typedef struct
{
  char *cur; // current parser pointer
  char *end; // end of input string
  const char *err; // parse error, if != 0
  U32 flags;  // F_*
  U32 depth; // recursion depth
  U32 maxdepth; // recursion depth limit
} dec_t;

static void
decode_ws (dec_t *dec)
{
  for (;;)
    {
      char ch = *dec->cur;

      if (ch > 0x20
          || (ch != 0x20 && ch != 0x0a && ch != 0x0d && ch != 0x09)) 
        break;

      ++dec->cur;
    }
}

#define ERR(reason) SB dec->err = reason; goto fail; SE

#define EXPECT_CH(ch) SB \
  if (*dec->cur != ch)		\
    ERR (# ch " expected");	\
  ++dec->cur;			\
  SE

#define DEC_INC_DEPTH if (++dec->depth > dec->maxdepth) ERR ("json datastructure exceeds maximum nesting level (set a higher max_depth)")
#define DEC_DEC_DEPTH --dec->depth

static SV *decode_sv (dec_t *dec);

static signed char decode_hexdigit[256];

static UV
decode_4hex (dec_t *dec)
{
  signed char d1, d2, d3, d4;
  unsigned char *cur = (unsigned char *)dec->cur;

  d1 = decode_hexdigit [cur [0]]; if (d1 < 0) ERR ("four hexadecimal digits expected");
  d2 = decode_hexdigit [cur [1]]; if (d2 < 0) ERR ("four hexadecimal digits expected");
  d3 = decode_hexdigit [cur [2]]; if (d3 < 0) ERR ("four hexadecimal digits expected");
  d4 = decode_hexdigit [cur [3]]; if (d4 < 0) ERR ("four hexadecimal digits expected");

  dec->cur += 4;

  return ((UV)d1) << 12
       | ((UV)d2) <<  8
       | ((UV)d3) <<  4
       | ((UV)d4);

fail:
  return (UV)-1;
}

static SV *
decode_str (dec_t *dec)
{
  SV *sv = 0;
  int utf8 = 0;

  do
    {
      char buf [SHORT_STRING_LEN + UTF8_MAX_LEN];
      char *cur = buf;

      do
        {
          unsigned char ch = *(unsigned char *)dec->cur++;

          if (ch == '"')
            {
              --dec->cur;
              break;
            }
          else if (ch == '\\')
            {
              switch (*dec->cur)
                {
                  case '\\':
                  case '/':
                  case '"': *cur++ = *dec->cur++; break;

                  case 'b': ++dec->cur; *cur++ = '\010'; break;
                  case 't': ++dec->cur; *cur++ = '\011'; break;
                  case 'n': ++dec->cur; *cur++ = '\012'; break;
                  case 'f': ++dec->cur; *cur++ = '\014'; break;
                  case 'r': ++dec->cur; *cur++ = '\015'; break;

                  case 'u':
                    {
                      UV lo, hi;
                      ++dec->cur;

                      hi = decode_4hex (dec);
                      if (hi == (UV)-1)
                        goto fail;

                      // possibly a surrogate pair
                      if (hi >= 0xd800)
                        if (hi < 0xdc00)
                          {
                            if (dec->cur [0] != '\\' || dec->cur [1] != 'u')
                              ERR ("missing low surrogate character in surrogate pair");

                            dec->cur += 2;

                            lo = decode_4hex (dec);
                            if (lo == (UV)-1)
                              goto fail;

                            if (lo < 0xdc00 || lo >= 0xe000)
                              ERR ("surrogate pair expected");

                            hi = (hi - 0xD800) * 0x400 + (lo - 0xDC00) + 0x10000;
                          }
                        else if (hi < 0xe000)
                          ERR ("missing high surrogate character in surrogate pair");

                      if (hi >= 0x80)
                        {
                          utf8 = 1;

                          cur = (char *)uvuni_to_utf8_flags (cur, hi, 0);
                        }
                      else
                        *cur++ = hi;
                    }
                    break;

                  default:
                    --dec->cur;
                    ERR ("illegal backslash escape sequence in string");
                }
            }
          else if (ch >= 0x20 && ch <= 0x7f)
            *cur++ = ch;
          else if (ch >= 0x80)
            {
              --dec->cur;

              STRLEN clen;
              UV uch = decode_utf8 (dec->cur, dec->end - dec->cur, &clen);
              if (clen == (STRLEN)-1)
                ERR ("malformed UTF-8 character in JSON string");

              do
                *cur++ = *dec->cur++;
              while (--clen);

              utf8 = 1;
            }
          else
            {
              --dec->cur;

              if (!ch)
                ERR ("unexpected end of string while parsing JSON string");
              else
                ERR ("invalid character encountered while parsing JSON string");
            }
        }
      while (cur < buf + SHORT_STRING_LEN);

      STRLEN len = cur - buf;

      if (sv)
        {
          SvGROW (sv, SvCUR (sv) + len + 1);
          memcpy (SvPVX (sv) + SvCUR (sv), buf, len);
          SvCUR_set (sv, SvCUR (sv) + len);
        }
      else
        sv = newSVpvn (buf, len);
    }
  while (*dec->cur != '"');

  ++dec->cur;

  if (sv)
    {
      SvPOK_only (sv);
      *SvEND (sv) = 0;

      if (utf8)
        SvUTF8_on (sv);
    }
  else
    sv = newSVpvn ("", 0);

  return sv;

fail:
  return 0;
}

static SV *
decode_num (dec_t *dec)
{
  int is_nv = 0;
  char *start = dec->cur;

  // [minus]
  if (*dec->cur == '-')
    ++dec->cur;

  if (*dec->cur == '0')
    {
      ++dec->cur;
      if (*dec->cur >= '0' && *dec->cur <= '9')
         ERR ("malformed number (leading zero must not be followed by another digit)");
    }
  else if (*dec->cur < '0' || *dec->cur > '9')
    ERR ("malformed number (no digits after initial minus)");
  else
    do
      {
        ++dec->cur;
      }
    while (*dec->cur >= '0' && *dec->cur <= '9');

  // [frac]
  if (*dec->cur == '.')
    {
      ++dec->cur;

      if (*dec->cur < '0' || *dec->cur > '9')
        ERR ("malformed number (no digits after decimal point)");

      do
        {
          ++dec->cur;
        }
      while (*dec->cur >= '0' && *dec->cur <= '9');

      is_nv = 1;
    }

  // [exp]
  if (*dec->cur == 'e' || *dec->cur == 'E')
    {
      ++dec->cur;

      if (*dec->cur == '-' || *dec->cur == '+')
        ++dec->cur;

      if (*dec->cur < '0' || *dec->cur > '9')
        ERR ("malformed number (no digits after exp sign)");

      do
        {
          ++dec->cur;
        }
      while (*dec->cur >= '0' && *dec->cur <= '9');

      is_nv = 1;
    }

  if (!is_nv)
    {
      UV uv;
      int numtype = grok_number (start, dec->cur - start, &uv);
      if (numtype & IS_NUMBER_IN_UV)
        if (numtype & IS_NUMBER_NEG)
          {
            if (uv < (UV)IV_MIN)
              return newSViv (-(IV)uv);
          }
        else
          return newSVuv (uv);
    }

  return newSVnv (Atof (start));

fail:
  return 0;
}

static SV *
decode_av (dec_t *dec)
{
  AV *av = newAV ();

  DEC_INC_DEPTH;
  decode_ws (dec);

  if (*dec->cur == ']')
    ++dec->cur;
  else
    for (;;)
      {
        SV *value;

        value = decode_sv (dec);
        if (!value)
          goto fail;

        av_push (av, value);

        decode_ws (dec);

        if (*dec->cur == ']')
          {
            ++dec->cur;
            break;
          }
        
        if (*dec->cur != ',')
          ERR (", or ] expected while parsing array");

        ++dec->cur;
      }

  DEC_DEC_DEPTH;
  return newRV_noinc ((SV *)av);

fail:
  SvREFCNT_dec (av);
  DEC_DEC_DEPTH;
  return 0;
}

static SV *
decode_hv (dec_t *dec)
{
  HV *hv = newHV ();

  DEC_INC_DEPTH;
  decode_ws (dec);

  if (*dec->cur == '}')
    ++dec->cur;
  else
    for (;;)
      {
        SV *key, *value;

        decode_ws (dec); EXPECT_CH ('"');

        key = decode_str (dec);
        if (!key)
          goto fail;

        decode_ws (dec); EXPECT_CH (':');

        value = decode_sv (dec);
        if (!value)
          {
            SvREFCNT_dec (key);
            goto fail;
          }

        hv_store_ent (hv, key, value, 0);
        SvREFCNT_dec (key);

        decode_ws (dec);

        if (*dec->cur == '}')
          {
            ++dec->cur;
            break;
          }

        if (*dec->cur != ',')
          ERR (", or } expected while parsing object/hash");

        ++dec->cur;
      }

  DEC_DEC_DEPTH;
  return newRV_noinc ((SV *)hv);

fail:
  SvREFCNT_dec (hv);
  DEC_DEC_DEPTH;
  return 0;
}

static SV *
decode_sv (dec_t *dec)
{
  decode_ws (dec);
  switch (*dec->cur)
    {
      case '"': ++dec->cur; return decode_str (dec); 
      case '[': ++dec->cur; return decode_av (dec); 
      case '{': ++dec->cur; return decode_hv (dec);

      case '-':
      case '0': case '1': case '2': case '3': case '4':
      case '5': case '6': case '7': case '8': case '9':
        return decode_num (dec);

      case 't':
        if (dec->end - dec->cur >= 4 && !memcmp (dec->cur, "true", 4))
          {
            dec->cur += 4;
            return newSViv (1);
          }
        else
          ERR ("'true' expected");

        break;

      case 'f':
        if (dec->end - dec->cur >= 5 && !memcmp (dec->cur, "false", 5))
          {
            dec->cur += 5;
            return newSViv (0);
          }
        else
          ERR ("'false' expected");

        break;

      case 'n':
        if (dec->end - dec->cur >= 4 && !memcmp (dec->cur, "null", 4))
          {
            dec->cur += 4;
            return newSVsv (&PL_sv_undef);
          }
        else
          ERR ("'null' expected");

        break;

      default:
        ERR ("malformed JSON string, neither array, object, number, string or atom");
        break;
    }

fail:
  return 0;
}

static SV *
decode_json (SV *string, U32 flags)
{
  SV *sv;

  SvUPGRADE (string, SVt_PV);

  if (flags & F_UTF8)
    sv_utf8_downgrade (string, 0);
  else
    sv_utf8_upgrade (string);

  SvGROW (string, SvCUR (string) + 1); // should basically be a NOP

  dec_t dec;
  dec.flags    = flags;
  dec.cur      = SvPVX (string);
  dec.end      = SvEND (string);
  dec.err      = 0;
  dec.depth    = 0;
  dec.maxdepth = DEC_DEPTH (dec.flags);

  *dec.end = 0; // this should basically be a nop, too, but make sure its there
  sv = decode_sv (&dec);

  if (!sv)
    {
      IV offset = dec.flags & F_UTF8
                  ? dec.cur - SvPVX (string)
                  : utf8_distance (dec.cur, SvPVX (string));
      SV *uni = sv_newmortal ();

      // horrible hack to silence warning inside pv_uni_display
      COP cop = *PL_curcop;
      cop.cop_warnings = pWARN_NONE;
      ENTER;
      SAVEVPTR (PL_curcop);
      PL_curcop = &cop;
      pv_uni_display (uni, dec.cur, dec.end - dec.cur, 20, UNI_DISPLAY_QQ);
      LEAVE;

      croak ("%s, at character offset %d [\"%s\"]",
             dec.err,
             (int)offset,
             dec.cur != dec.end ? SvPV_nolen (uni) : "(end of string)");
    }

  sv = sv_2mortal (sv);

  if (!(dec.flags & F_ALLOW_NONREF) && !SvROK (sv))
    croak ("JSON text must be an object or array (but found number, string, true, false or null, use allow_nonref to allow this)");

  return sv;
}

/////////////////////////////////////////////////////////////////////////////
// XS interface functions

MODULE = JSON::XS		PACKAGE = JSON::XS

BOOT:
{
	int i;

        memset (decode_hexdigit, 0xff, 256);

        for (i = 0; i < 256; ++i)
          decode_hexdigit [i] =
            i >= '0' && i <= '9' ? i - '0'
            : i >= 'a' && i <= 'f' ? i - 'a' + 10
            : i >= 'A' && i <= 'F' ? i - 'A' + 10
            : -1;

	json_stash = gv_stashpv ("JSON::XS", 1);
}

PROTOTYPES: DISABLE

SV *new (char *dummy)
	CODE:
        RETVAL = sv_bless (newRV_noinc (newSVuv (F_DEFAULT)), json_stash);
	OUTPUT:
        RETVAL

SV *ascii (SV *self, int enable = 1)
	ALIAS:
        ascii        = F_ASCII
        utf8         = F_UTF8
        indent       = F_INDENT
        canonical    = F_CANONICAL
        space_before = F_SPACE_BEFORE
        space_after  = F_SPACE_AFTER
        pretty       = F_PRETTY
        allow_nonref = F_ALLOW_NONREF
        shrink       = F_SHRINK
	CODE:
{
  	UV *uv = SvJSON (self);
        if (enable)
          *uv |=  ix;
        else
          *uv &= ~ix;

        RETVAL = newSVsv (self);
}
	OUTPUT:
        RETVAL

SV *max_depth (SV *self, int max_depth = 0x80000000UL)
	CODE:
{
  	UV *uv = SvJSON (self);
        UV log2 = 0;

        if (max_depth > 0x80000000UL) max_depth = 0x80000000UL;

        while ((1UL << log2) < max_depth)
          ++log2;

        *uv = *uv & ~F_MAXDEPTH | (log2 << S_MAXDEPTH);

        RETVAL = newSVsv (self);
}
	OUTPUT:
        RETVAL

void encode (SV *self, SV *scalar)
	PPCODE:
        XPUSHs (encode_json (scalar, *SvJSON (self)));

void decode (SV *self, SV *jsonstr)
	PPCODE:
        XPUSHs (decode_json (jsonstr, *SvJSON (self)));

PROTOTYPES: ENABLE

void to_json (SV *scalar)
	ALIAS:
        objToJson = 0
	PPCODE:
        XPUSHs (encode_json (scalar, F_DEFAULT | F_UTF8));

void from_json (SV *jsonstr)
	ALIAS:
        jsonToObj = 0
	PPCODE:
        XPUSHs (decode_json (jsonstr, F_DEFAULT | F_UTF8));


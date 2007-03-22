#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "assert.h"
#include "string.h"
#include "stdlib.h"

#define F_ASCII        0x00000001
#define F_UTF8         0x00000002
#define F_INDENT       0x00000004
#define F_CANONICAL    0x00000008
#define F_SPACE_BEFORE 0x00000010
#define F_SPACE_AFTER  0x00000020
#define F_JSON_RPC     0x00000040
#define F_ALLOW_NONREF 0x00000080

#define F_PRETTY    F_INDENT | F_SPACE_BEFORE | F_SPACE_AFTER
#define F_DEFAULT   0

#define INIT_SIZE   32 // initial scalar size to be allocated

#define SB do {
#define SE } while (0)

static HV *json_stash;

// structure used for encoding JSON
typedef struct
{
  char *cur;
  STRLEN len; // SvLEN (sv)
  char *end;  // SvEND (sv)
  SV *sv;
  UV flags;
  int max_recurse;
  int indent;
} enc_t;

// structure used for decoding JSON
typedef struct
{
  char *cur;
  char *end;
  const char *err;
  UV flags;
} dec_t;

static UV *
SvJSON (SV *sv)
{
  if (!(SvROK (sv) && SvOBJECT (SvRV (sv)) && SvSTASH (SvRV (sv)) == json_stash))
    croak ("object is not of type JSON::XS");

  return &SvUVX (SvRV (sv));
}

/////////////////////////////////////////////////////////////////////////////

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

      if (ch == '"')
        {
          need (enc, len += 1);
          *enc->cur++ = '\\';
          *enc->cur++ = '"';
          ++str;
        }
      else if (ch == '\\')
        {
          need (enc, len += 1);
          *enc->cur++ = '\\';
          *enc->cur++ = '\\';
          ++str;
        }
      else if (ch >= 0x20 && ch < 0x80) // most common case
        {
          *enc->cur++ = ch;
          ++str;
        }
      else if (ch == '\015')
        {
          need (enc, len += 1);
          *enc->cur++ = '\\';
          *enc->cur++ = 'r';
          ++str;
        }
      else if (ch == '\012')
        {
          need (enc, len += 1);
          *enc->cur++ = '\\';
          *enc->cur++ = 'n';
          ++str;
        }
      else
        {
          STRLEN clen;
          UV uch;

          if (is_utf8)
            {
              uch = utf8n_to_uvuni (str, end - str, &clen, UTF8_CHECK_ONLY);
              if (clen == (STRLEN)-1)
                croak ("malformed UTF-8 character in string, cannot convert to JSON");
            }
          else
            {
              uch = ch;
              clen = 1;
            }

          if (uch < 0x80 || enc->flags & F_ASCII)
            {
              if (uch > 0xFFFFUL)
                {
                  need (enc, len += 11);
                  sprintf (enc->cur, "\\u%04x\\u%04x",
                           (uch - 0x10000) / 0x400 + 0xD800,
                           (uch - 0x10000) % 0x400 + 0xDC00);
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
              need (enc, 10); // never more than 11 bytes needed
              enc->cur = uvuni_to_utf8_flags (enc->cur, uch, 0);
              ++str;
            }
        }

      --len;
    }
}

#define INDENT SB \
  if (enc->flags & F_INDENT)		\
    {					\
      int i_;				\
      need (enc, enc->indent);		\
      for (i_ = enc->indent * 3; i_--; )\
        encode_ch (enc, ' ');		\
    }					\
  SE

#define SPACE SB need (enc, 1); encode_ch (enc, ' '); SE
#define NL    SB if (enc->flags & F_INDENT) { need (enc, 1); encode_ch (enc, '\n'); } SE
#define COMMA SB \
  encode_ch (enc, ',');			\
  if (enc->flags & F_INDENT)		\
    NL;					\
  else if (enc->flags & F_SPACE_AFTER)	\
    SPACE;				\
  SE

static void encode_sv (enc_t *enc, SV *sv);

static void
encode_av (enc_t *enc, AV *av)
{
  int i, len = av_len (av);

  encode_ch (enc, '['); NL;
  ++enc->indent;

  for (i = 0; i <= len; ++i)
    {
      INDENT;
      encode_sv (enc, *av_fetch (av, i, 0));

      if (i < len)
        COMMA;
    }

  NL;

  --enc->indent;
  INDENT; encode_ch (enc, ']');
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

  if (enc->flags & F_SPACE_BEFORE) SPACE;
  encode_ch (enc, ':');
  if (enc->flags & F_SPACE_AFTER ) SPACE;
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

  if (!(cmp == memcmp (HeKEY (a), HeKEY (b), la < lb ? la : lb)))
    cmp = la < lb ? -1 : la == lb ? 0 : 1;

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

  encode_ch (enc, '{'); NL; ++enc->indent;

  if ((count = hv_iterinit (hv)))
    {
      // for canonical output we have to sort by keys first
      // actually, this is mostly due to the stupid so-called
      // security workaround added somewhere in 5.8.x.
      // that randomises hash orderings
      if (enc->flags & F_CANONICAL)
        {
          HE *he, *hes [count];
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
              // hack to disable "use bytes"
              COP *oldcop = PL_curcop, cop;
              cop.op_private = 0;
              PL_curcop = &cop;

              SAVETMPS;
              qsort (hes, count, sizeof (HE *), he_cmp_slow);
              FREETMPS;

              PL_curcop = oldcop;
            }

          for (i = 0; i < count; ++i)
            {
              INDENT;
              encode_he (enc, hes [i]);

              if (i < count - 1)
                COMMA;
            }

          NL;
        }
      else
        {
          SV *sv;
          HE *he = hv_iternext (hv);

          for (;;)
            {
              INDENT;
              encode_he (enc, he);

              if (!(he = hv_iternext (hv)))
                break;

              COMMA;
            }

          NL;
        }
    }

  --enc->indent; INDENT; encode_ch (enc, '}');
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
    {
      if (!--enc->max_recurse)
        croak ("data structure too deep (hit recursion limit)");

      sv = SvRV (sv);

      switch (SvTYPE (sv))
        {
          case SVt_PVAV: encode_av (enc, (AV *)sv); break;
          case SVt_PVHV: encode_hv (enc, (HV *)sv); break;

          default:
            croak ("JSON can only represent references to arrays or hashes");
        }
    }
  else if (!SvOK (sv))
    encode_str (enc, "null", 4, 0);
  else
    croak ("encountered perl type that JSON cannot handle");
}

static SV *
encode_json (SV *scalar, UV flags)
{
  if (!(flags & F_ALLOW_NONREF) && !SvROK (scalar))
    croak ("hash- or arraref required (not a simple scalar, use allow_nonref to allow this)");

  enc_t enc;
  enc.flags       = flags;
  enc.sv          = sv_2mortal (NEWSV (0, INIT_SIZE));
  enc.cur         = SvPVX (enc.sv);
  enc.end         = SvEND (enc.sv);
  enc.max_recurse = 0;
  enc.indent      = 0;

  SvPOK_only (enc.sv);
  encode_sv (&enc, scalar);

  if (!(flags & (F_ASCII | F_UTF8)))
    SvUTF8_on (enc.sv);

  SvCUR_set (enc.sv, enc.cur - SvPVX (enc.sv));
  return enc.sv;
}

/////////////////////////////////////////////////////////////////////////////

#define WS \
  for (;;)				\
    {					\
      char ch = *dec->cur;		\
      if (ch > 0x20			\
          || (ch != 0x20 && ch != 0x0a && ch != 0x0d && ch != 0x09)) \
        break;				\
      ++dec->cur;			\
    }

#define ERR(reason) SB dec->err = reason; goto fail; SE
#define EXPECT_CH(ch) SB \
  if (*dec->cur != ch)		\
    ERR (# ch " expected");	\
  ++dec->cur;			\
  SE

static SV *decode_sv (dec_t *dec);

static signed char decode_hexdigit[256];

static UV
decode_4hex (dec_t *dec)
{
  signed char d1, d2, d3, d4;

  d1 = decode_hexdigit [((unsigned char *)dec->cur) [0]];
  if (d1 < 0) ERR ("four hexadecimal digits expected");
  d2 = decode_hexdigit [((unsigned char *)dec->cur) [1]];
  if (d2 < 0) ERR ("four hexadecimal digits expected");
  d3 = decode_hexdigit [((unsigned char *)dec->cur) [2]];
  if (d3 < 0) ERR ("four hexadecimal digits expected");
  d4 = decode_hexdigit [((unsigned char *)dec->cur) [3]];
  if (d4 < 0) ERR ("four hexadecimal digits expected");

  dec->cur += 4;

  return ((UV)d1) << 12
       | ((UV)d2) <<  8
       | ((UV)d3) <<  4
       | ((UV)d4);

fail:
  return (UV)-1;
}

#define APPEND_GROW(n) SB \
  if (cur + (n) >= end)				\
    {						\
      STRLEN ofs = cur - SvPVX (sv);		\
      SvGROW (sv, ofs + (n) + 1);		\
      cur = SvPVX (sv) + ofs;			\
      end = SvEND (sv);				\
    }						\
  SE

#define APPEND_CH(ch) SB \
  APPEND_GROW (1);	\
  *cur++ = (ch);	\
  SE

static SV *
decode_str (dec_t *dec)
{
  SV *sv = NEWSV (0,2);
  int utf8 = 0;
  char *cur = SvPVX (sv);
  char *end = SvEND (sv);

  for (;;)
    {
      unsigned char ch = *(unsigned char *)dec->cur;

      if (ch == '"')
        break;
      else if (ch == '\\')
        {
          switch (*++dec->cur)
            {
              case '\\':
              case '/':
              case '"': APPEND_CH (*dec->cur++); break;

              case 'b': APPEND_CH ('\010'); ++dec->cur; break;
              case 't': APPEND_CH ('\011'); ++dec->cur; break;
              case 'n': APPEND_CH ('\012'); ++dec->cur; break;
              case 'f': APPEND_CH ('\014'); ++dec->cur; break;
              case 'r': APPEND_CH ('\015'); ++dec->cur; break;

              case 'u':
                {
                  UV lo, hi;
                  ++dec->cur;

                  hi = decode_4hex (dec);
                  if (hi == (UV)-1)
                    goto fail;

                  // possibly a surrogate pair
                  if (hi >= 0xd800 && hi < 0xdc00)
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
                  else if (hi >= 0xdc00 && hi < 0xe000)
                    ERR ("missing high surrogate character in surrogate pair");

                  if (hi >= 0x80)
                    {
                      utf8 = 1;

                      APPEND_GROW (4); // at most 4 bytes for 21 bits
                      cur = (char *)uvuni_to_utf8_flags (cur, hi, 0);
                    }
                  else
                    APPEND_CH (hi);
                }
                break;

              default:
                --dec->cur;
                ERR ("illegal backslash escape sequence in string");
            }
        }
      else if (ch >= 0x20 && ch <= 0x7f)
        APPEND_CH (*dec->cur++);
      else if (ch >= 0x80)
        {
          STRLEN clen;
          UV uch = utf8n_to_uvuni (dec->cur, dec->end - dec->cur, &clen, UTF8_CHECK_ONLY);
          if (clen == (STRLEN)-1)
            ERR ("malformed UTF-8 character in string, cannot convert to JSON");

          APPEND_GROW (clen);
          do
            {
              *cur++ = *dec->cur++;
            }
          while (--clen);

          utf8 = 1;
        }
      else if (dec->cur == dec->end)
        ERR ("unexpected end of string while parsing json string");
      else
        ERR ("invalid character encountered");
    }

  ++dec->cur;

  SvCUR_set (sv, cur - SvPVX (sv));

  SvPOK_only (sv);
  *SvEND (sv) = 0;

  if (utf8)
    SvUTF8_on (sv);

  return sv;

fail:
  SvREFCNT_dec (sv);
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

  WS;
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

        WS;

        if (*dec->cur == ']')
          {
            ++dec->cur;
            break;
          }
        
        if (*dec->cur != ',')
          ERR (", or ] expected while parsing array");

        ++dec->cur;
      }

  return newRV_noinc ((SV *)av);

fail:
  SvREFCNT_dec (av);
  return 0;
}

static SV *
decode_hv (dec_t *dec)
{
  HV *hv = newHV ();

  WS;
  if (*dec->cur == '}')
    ++dec->cur;
  else
    for (;;)
      {
        SV *key, *value;

        WS; EXPECT_CH ('"');

        key = decode_str (dec);
        if (!key)
          goto fail;

        WS; EXPECT_CH (':');

        value = decode_sv (dec);
        if (!value)
          {
            SvREFCNT_dec (key);
            goto fail;
          }

        //TODO: optimise
        hv_store_ent (hv, key, value, 0);

        WS;

        if (*dec->cur == '}')
          {
            ++dec->cur;
            break;
          }

        if (*dec->cur != ',')
          ERR (", or } expected while parsing object/hash");

        ++dec->cur;
      }

  return newRV_noinc ((SV *)hv);

fail:
  SvREFCNT_dec (hv);
  return 0;
}

static SV *
decode_sv (dec_t *dec)
{
  WS;
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
        ERR ("malformed json string");
        break;
    }

fail:
  return 0;
}

static SV *
decode_json (SV *string, UV flags)
{
  SV *sv;

  if (flags & F_UTF8)
    sv_utf8_downgrade (string, 0);
  else
    sv_utf8_upgrade (string);

  SvGROW (string, SvCUR (string) + 1); // should basically be a NOP

  dec_t dec;
  dec.flags = flags;
  dec.cur   = SvPVX (string);
  dec.end   = SvEND (string);
  dec.err   = 0;

  sv = decode_sv (&dec);

  if (!sv)
    {
      IV offset = utf8_distance (dec.cur, SvPVX (string));
      SV *uni = sv_newmortal ();
      // horrible hack to silence warning inside pv_uni_display
      COP cop;
      memset (&cop, 0, sizeof (cop));
      cop.cop_warnings = pWARN_NONE;
      SAVEVPTR (PL_curcop);
      PL_curcop = &cop;

      pv_uni_display (uni, dec.cur, dec.end - dec.cur, 20, UNI_DISPLAY_QQ);
      croak ("%s, at character offset %d (%s)",
             dec.err,
             (int)offset,
             dec.cur != dec.end ? SvPV_nolen (uni) : "(end of string)");
    }

  sv = sv_2mortal (sv);

  if (!(dec.flags & F_ALLOW_NONREF) && !SvROK (sv))
    croak ("JSON object or array expected (but number, string, true, false or null found, use allow_nonref to allow this)");

  return sv;
}

MODULE = JSON::XS		PACKAGE = JSON::XS

BOOT:
{
	int i;

        memset (decode_hexdigit, 0xff, 256);
        for (i = 10; i--; )
          decode_hexdigit ['0' + i] = i;

        for (i = 7; i--; )
          {
            decode_hexdigit ['a' + i] = 10 + i;
            decode_hexdigit ['A' + i] = 10 + i;
          }

	json_stash = gv_stashpv ("JSON::XS", 1);
}

PROTOTYPES: DISABLE

SV *new (char *dummy)
	CODE:
        RETVAL = sv_bless (newRV_noinc (newSVuv (F_DEFAULT)), json_stash);
	OUTPUT:
        RETVAL

SV *ascii (SV *self, int enable)
	ALIAS:
        ascii        = F_ASCII
        utf8         = F_UTF8
        indent       = F_INDENT
        canonical    = F_CANONICAL
        space_before = F_SPACE_BEFORE
        space_after  = F_SPACE_AFTER
        json_rpc     = F_JSON_RPC
        pretty       = F_PRETTY
        allow_nonref = F_ALLOW_NONREF
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

void encode (SV *self, SV *scalar)
	PPCODE:
        XPUSHs (encode_json (scalar, *SvJSON (self)));

void decode (SV *self, SV *jsonstr)
	PPCODE:
        XPUSHs (decode_json (jsonstr, *SvJSON (self)));

PROTOTYPES: ENABLE

void to_json (SV *scalar)
	PPCODE:
        XPUSHs (encode_json (scalar, F_UTF8));

void from_json (SV *jsonstr)
	PPCODE:
        XPUSHs (decode_json (jsonstr, F_UTF8));


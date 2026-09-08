# -*- perl -*-
use strict;
use warnings;
use Test::More;

plan skip_all => 'This test is only run for the module author'
  unless -d '.git' || $ENV{AUTHOR_TESTING};

eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required to discover POD files" if $@;

eval "use Pod::Checker";
plan skip_all => "Pod::Checker required for strict POD syntax checking" if $@;

my @files = all_pod_files();
plan skip_all => "no POD files found" unless @files;

plan tests => scalar @files;

# Test::Pod (Pod::Simple) accepts POD that Pod::Checker flags as broken,
# e.g. unresolved L<> links to non-existent =item/=head targets, or
# malformed whitespace-only lines inside verbatim paragraphs. Run the
# stricter, older podchecker syntax checker over the same file list.
for my $file (@files) {
    my $report = '';
    open my $fh, '>', \$report or die "in-memory filehandle: $!";
    my $checker = Pod::Checker->new(-quiet => 1);
    $checker->parse_from_file($file, $fh);
    close $fh;

    my $errors   = $checker->num_errors;
    my $warnings = $checker->num_warnings;

    ok(($errors <= 0) && ($warnings == 0), "$file has no Pod::Checker errors or warnings")
      or diag($report);
}

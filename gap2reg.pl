#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Std;

my %opts = (l=>1000, L=>10000000);
getopts("l:L:c", \%opts);

die("Usage: gap2reg.pl [options] <ref.fai> <gap.txt>
Options:
  -l INT        min gap length [$opts{l}]
  -L INT        min region length [$opts{L}]
  -c            keep chromosomal sequences only

Note: 'ref.fai' is generated by faidx; 'gap.txt' can be obtained from:
  http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/gap.txt.gz
  http://hgdownload.soe.ucsc.edu/goldenPath/hg38/database/gap.txt.gz
") if @ARGV < 2;

# read chromosome length
my (%len, @seq);
open(FH, $ARGV[0]) || die;
while (<FH>) {
	chomp;
	my @t = split("\t");
	$len{$t[0]} = $t[1];
	push(@seq, $t[0]);
}
close(FH);

# read the gap file
my %gap;
open(FH, $ARGV[1] =~ /\.gz$/? "gzip -dc $ARGV[1] |" : $ARGV[1]) || die;
while (<FH>) {
	chomp;
	my @t = split("\t");
	next unless defined($len{$t[1]});
	next if $t[3] - $t[2] < $opts{l};
	push(@{$gap{$t[1]}}, [$t[2], $t[3]]);
}
close(FH);

# generate the region
for my $s (@seq) {
	my $name = $s;
	if (defined $opts{c}) {
		next if $s =~ /^chr.*_(random|alt|decoy)$/;
		next if $s =~ /^chr(Un|M|EBV)/;
		next if $s =~ /^HLA/;
	}
	if (!defined $gap{$s}) {
		print "$s\t0\t", $len{$s}, "\n";
	} else {
		my @g = sort{$a->[0]<=>$b->[0]} @{$gap{$s}};
		my ($st, $en) = (0, 0);
		for my $x (@g) {
			if ($x->[0] == 0) {
				$st = $en = $x->[1];
			} else {
				$en = $x->[0];
				if ($en - $st >= $opts{L}) {
					print join("\t", $name, $st, $en), "\n";
					$st = $en = $x->[1];
				}
			}
		}
		if ($en != 0 && $st != $en) {
			print join("\t", $name, $st, $en), "\n";
		}
	}
}

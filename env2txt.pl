#!/usr/bin/perl

# convert enVision extracts to a plaintext format consumable by other scripts.
# (we should convert directly to binary in this script, but there's some complexity to the
# error detection/correction that I'd rather not rewrite/absorb - easier to just feed properly-formatted
# plaintext to the existing - reliable - other scripts.)
#
# based on txt2iaa.pl, minus the binary output packing.
#
# sample input:
# Nov 17 08:00:59 [192.168.239.5] 1 2010-11-17T16:00:59.765Z w61 IB 8192184 IAALOG - 3256920376|c0a8f325007d00b84ce3fc3b2da44700|DI3986|IB|usr/westfieldbank/admin/ha/iaalog|1290009659765|-0500|account summary|||||026601214|173.166.15.46|1782466317|
#
# sample output:
# 2010/11/17 08:00:59|account summary|026601214|172.166.15.46|1782466317|

use strict;

my( $numArgs, $logfile, $toss, $data, @first, $time, $ts, $date, $year, $month, $day, $fdate, @s, @r, $body);

$numArgs = $#ARGV+1;

die "usage: $0 <filename>\n" unless $numArgs == 1;

$logfile = $ARGV[0];

open (LOG, "<$logfile") or die("unable to open $logfile: $!\n");

while (<LOG>) {
   chomp;
   @first = split(' ', $_);
   ($time,$ts) = @first[2,5];
   $date = substr($ts, 0, 10);
   my ($year,$month,$day) = split(/-/, $date);
   $fdate = "$year/$month/$day $time";
   ($toss, $data) = split(/\ \[/, $_, 2);
   # next 2 lines equivalent to "cut -d'|' -f8,13-"
   @s = split(/\|/, $data);
   @r = @s[7,12..@s-1];
   $body = join("|", @r);
   print $fdate, "|", $body, "\n";
}
close LOG;
exit(0);

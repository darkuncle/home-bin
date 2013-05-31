#!/usr/bin/perl
## Remove Control M's from the code.
#
# or just do "perl -pi -e 'tr/cM//d;' <filename>"
# or "perl -0777pli -015e0 <filename>"
# or "perl -lp015e1 ''"
#
$source=@ARGV[0];
if (!$source) { print "Must have source file!"; exit; }
$target=@ARGV[1];
if (!$target) { print "Must have target file!"; exit; }
open(SOURCE,"$source");
open(TARGET,">$target");
while (<SOURCE>)
{
  $_ =~ s/\cM\n/\n/g;
  print TARGET;
}
close(SOURCE);
close(TARGET);

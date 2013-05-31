#!/usr/bin/perl -w
use strict ;

my $target = shift || die "Usage: nuke_dupe <target_dir>\n" ;
opendir(TARGET, $target) || die "can't opendir $target: $!" ;
chdir $target ;
my @toplevel = readdir(TARGET) ;
closedir(TARGET) ;

my $file ;

foreach $file(@toplevel) {
  print $file."\n" ;
  if ( $file eq $target ) {
    system("rm -rf $file") ;
  }
}

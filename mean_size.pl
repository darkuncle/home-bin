#!/usr/local/bin/perl -w
use strict ;

# script to traverse an arbitrary directory tree and calculate the mean size
# of subdirectories. Really only useful for a situation in which you have
# many similar subdirectories.

my $target = shift || die "Usage: mean_size.pl <target_dir>\n" ;
my $du = "/bin/du" ;
my $find = "/bin/find" ;

my $subdir ;  
my $counter = 0 ;
my $size = 0 ;
my $total = 0 ;
my $average = 0 ;

sub is_empty {
  my $subdir = $_[0] ;
  opendir(SUB, $subdir) || die "What?! on $subdir: $!" ;
  my $x ;
  while(defined($x = readdir(SUB))) { 
    closedir(SUB), return 0 unless $x eq '.' or $x eq '..'
  }  
  closedir(SUB) ;
  return 1 ;
}

chdir($target) || die "Can't chdir to $target: $!" ;
opendir(INDIR, ".") or die "Can't opendir!?! $!" ;
while(defined($subdir = readdir(INDIR))) {
  ++$counter if $subdir =~ m/^\d/ and -d $subdir and !is_empty($subdir)
}
closedir(INDIR);

`du -sk` =~ m/(\d+)/ or die "WHUT?"; $size = $1;

unless ($counter == 0) { $average = $size/$counter }

print "$target disk space: $size\n" ;
print "$counter matching, non-empty subdirectories in $target\n" ;
printf "Average subdirectory size: %0.2f KB\n", $average ;

#!/usr/local/bin/perl
require 5;
package Audio::MP3Split;
# INITIAL TEST VERSION
# written by Sean Burke or Jeff Goff, I forget which.
# minor additional modifications by Scott Francis.

use strict;
use warnings;
use integer;
my $k = 1000; # default chunk size, in kilobytes

unless(caller) {
  if( @ARGV and $ARGV[0] =~ m/^-k(\d+)$/s ) {
    $k = 0 + $1;
    shift @ARGV;
    die "Can't have a 0K frameloids!\n" unless $k;
  }

  @ARGV or die "Usage:
mp3split files...
mp3split -kNUMBER files...
 Split mp3 files into roughly NUMBER kilobyte long segments.

Example:
  mp3split -k5000 speech.mp3
...splits speech.mp3 into roughly five-meg-long mp3s named
like speech.mp3.000, speech.mp3.001, speech.mp3.002, etc.

This program performs a simple binary split (so you can just
cat the originals back together, in order!, and get the original
file back), except that it only splits on MP3 frame boundaries,
so that each segment is a playable MP3 file on its own!

sburke\x40cpan.org
\n";

  foreach my $x (@ARGV) {
    print "$x\n";
    mp3_chunk($x);
  }
  print "Done.\n";
}

sub mp3_chunk {
  use Carp;
  my $in = $_[0];
  my $byte_limit = $k * 1024;
  croak "undef isn't a good filespec" unless defined $in;
  croak "empty-string isn't a good filespec" unless length $in;
  croak "$in isn't a readable file\n" unless -e $in and -f $in and -r $in;
  if(-s $in  < $byte_limit) {
    print "$in is already under $byte_limit bytes long!  Skipping.\n";
    return;
  }
  
  open(MP3IN, "< $in") or croak "Can't read-open $in: $!";
  binmode(MP3IN);
  
  my $byte_count;
  my $this_file_name;
  my $next_file = do {   # a lambda to kick open a new file
    my $counter = '000';
    sub {
      $this_file_name = sprintf "%s.%03d", $in, $counter++;
      close(MP3OUT) if fileno(MP3OUT);
      #print "Write-opening $this_file_name...\n";
      open(MP3OUT, "> $this_file_name")
       || carp "Can't write-open to $this_file_name: $!";
      binmode(MP3OUT);
      $byte_count = 0;
      return;
    }
  };
  
  $next_file->(); # start us out.
  
  my $buffer = '';
  while(1) {
    read(MP3IN, $buffer, 4096, length($buffer))
      || do {print MP3OUT $buffer if length $buffer; last};
    
    if($buffer =~ m/\A([^\xFF]*)(\xFF)(.*)\z/s) {
      unless(length $3) {  # We end on what might be a start-of-frame!
        if(length $1) {
          $byte_count += length($1);
          print MP3OUT $1;
          substr($buffer, 0,length($1)) = '';
        }
        next;
      }
      unless(ord($3) >= 224) {  # 0b1110_0000
        # Not really the start of a frame.  Ahwell.
        $byte_count += length($1) + length($2);
        print MP3OUT $1, $2;
        substr($buffer, 0, 1 + length($1)) = '';
        next;
      }

      # Otherwise it's a start-of-frame!
      if(length $1) {
        $byte_count += length($1);
        print MP3OUT $1;
      }
      # Only place we get to split is here!
      $next_file->() if $byte_count > $byte_limit;
      print MP3OUT $2, $3;
      $byte_count += length($2) + length($3);
      $buffer = '';
      
    } else {
      # No synch in this buffer
      $byte_count += length($buffer);
      print MP3OUT $buffer if length $buffer;
    }
  }
  close(MP3OUT) if fileno(MP3OUT);
  close(MP3IN);
  
}



1;

__END__

Frame starts on two bytes:
  AAAAAAAA AAAxxxx
  11111111 111xxxx



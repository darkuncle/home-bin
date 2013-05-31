#!/usr/bin/perl
#
# parse through gzipped access logs and extract data (like the number of hits
# per state in the US)
#
# SAMPLE LOGFILE INPUT LINE (no line breaks):
####
# 66.135.144.9 www.example.com - [31/Mar/2003:23:53:57 -0800] "GET /News/index.html HTTP/1.0" 200 23725 "http://www.example.com/Multimedia/index.html" "Mozilla/4.0 (compatible; MSIE 6.0; Windows 98; Win 9x 4.90)" US WA CTL0000B400D2C90E413F5294CBD888C2E5
####
# the fields are as described below (the request above has no username,
# hence the '-')
#
# the output of the script using the above line as input should be
# something like "WA - 1"
#
# TODO
# until we get this into subs, uncomment the loop of the function you're after
# (i.e. uncomment requests by state and comment all the others if that's all you need)

use FileHandle;
use POSIX;
use Compress::Zlib;

my @files = @ARGV;

foreach $file (@files) {
  my $gz = gzopen("$file", "r");
  while ($gz->gzreadline($_)) {
    my ($ip, $hostname, $username, $date, $rqst, $code, $bytes, $referrer, $agent, $country, $state, $engageID);
    chomp;

# grab the fields from the log entry
# split /[ "\[\]]/ # suggested by confound rather than the following regex
    if (/^(\S+) (\S+) (\S+) \[(\S+ \S+)\] \"(.*?)\" (\S+) (\S+) \"(.*?)\" \"(.*)\" (\S+) (\S+) (\S+)$/) {
      ($ip, $hostname, $username, $date, $rqst, $code, $bytes, $referrer, $agent, $country, $state, $engageID) = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12);
    } # endif

# BEGIN STATE REQUEST PROCESSING
#    if ($country eq 'US') {
#      if ($state ne '-') {
#        $states{$state}++;
#      }
#    }
# END STATE REQUEST PROCESSING

# BEGIN USER-AGENT PROCESSING
    # skip entries from bots
    if ($agent =~ /bot|crawler/i) { next; }

    # Linux user-agents
    elsif ($agent =~ /Linux/) {
      $linux++;
      if    ($agent =~ /Opera/) { $opnix++; next; }
      elsif ($agent =~ /Konqueror/) { $konqnix++; next; }
      elsif ($agent =~ /Netscape\/6/) { $net6nix++; next; }
      elsif ($agent =~ /Netscape\/7/) { $net7nix++; next; }
      elsif ($agent =~ /Galeon/) { $galnix++; next; }
      elsif ($agent =~ /Firebird/) { $firenix++; next; }
      elsif ($agent =~ /Mozilla/) { $moznix++; next; }
      else { next; } # skip other user-agents
    }

    # Windows user-agents
    # Mac user-agents
    elsif ($agent =~ /Mac/) {
      $mac++;
      if    ($agent =~ /Opera/) { $opmac++; next; }
      elsif ($agent =~ /MSIE 4/) { $ie4mac++; next; }
      elsif ($agent =~ /MSIE 5/) { $ie5mac++; next; }
      elsif ($agent =~ /Safari/) { $safari++; next; }
      elsif ($agent =~ /Camino|Firebird/) { $firemac++; next; }
      elsif ($agent =~ /Netscape\/4/) { $net4mac++; next; }
      elsif ($agent =~ /Netscape\/6/) { $net6mac++; next; }
      elsif ($agent =~ /Netscape\/7/) { $net7mac++; next; }
      elsif ($agent =~ /Gecko/) { $mozmac++; next; }
      else { next; } # skip other user-agents
    }  

    elsif ($agent =~ /Windows/) {
      $windows++;
      if    ($agent =~ /Opera/) { $opwin++; next; }
      elsif ($agent =~ /MSIE 4/) { $ie4win++; next; }
      elsif ($agent =~ /MSIE 5/) { $ie5win++; next; }
      elsif ($agent =~ /MSIE 6/) { $ie6win++; next; }
      elsif ($agent =~ /Netscape\/4/) { $net4win++; next; }
      elsif ($agent =~ /Netscape\/6/) { $net6win++; next; }
      elsif ($agent =~ /Netscape\/7/) { $net7win++; next; }
      elsif ($agent =~ /Firebird/) { $firewin++; next; }
      elsif ($agent =~ /Mozilla/) { $mozwin++; next; }
      else { next; } # skip other user-agents
    }

    # skip other OSes *sigh*
    else { next; }

# BEGIN USER-AGENT PROCESSING

  } # end while loop
  $gz->gzclose;
} # end foreach loop


# BEGIN STATE REQUEST OUTPUT
#foreach my $state (sort keys %states) {
#  print "$state - $states{$state}\n";
#}
# END STATE REQUEST OUTPUT

# BEGIN USER-AGENT REQUEST OUTPUT
print "User-agent report:\n";
print "==================\n\n";
print "Linux:\n";
print "  Opera: $opnix\n";
print "  Konqueror: $konqnix\n";
print "  Galeon: $galnix\n";
print "  Netscape 6: $net6nix\n";
print "  Netscape 7: $net7nix\n";
print "  Firebird: $firenix\n";
print "  Mozilla: $moznix\n\n";
print "MacOS:\n";
print "  Safari: $safari\n";
print "  Opera: $opmac\n";
print "  Netscape 4: $net4mac\n";
print "  Netscape 6: $net6mac\n";
print "  Netscape 7: $net7mac\n";
print "  Firebird: $firemac\n";
print "  Mozilla: $mozmac\n";
print "  MSIE 4: $ie4mac\n";
print "  MSIE 5: $ie5mac\n\n";
print "Windows:\n";
print "  Opera: $opwin\n";
print "  Netscape 4: $net4win\n";
print "  Netscape 6: $net6win\n";
print "  Netscape 7: $net7win\n";
print "  Firebird: $firewin\n";
print "  Mozilla: $mozwin\n";
print "  MSIE 4: $ie4win\n";
print "  MSIE 5: $ie5win\n";
print "  MSIE 6: $ie6win\n\n";
# END USER-AGENT REQUEST OUTPUT

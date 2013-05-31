#!/usr/bin/perl
# $Id: user-agents.pl,v 1.1 2006/01/11 03:24:19 sfrancis Exp $
# $Log: user-agents.pl,v $
# Revision 1.1  2006/01/11 03:24:19  sfrancis
# initial commit; need to add $Id$ to most files
#
# Revision 1.1  2004/04/23 15:53:59  sfrancis
# initial checkin; deprecates useragent_report.pl
#
#
# parse through gzipped access logs and extract data
# (such as user-agent statistics)
#
# SAMPLE LOGFILE INPUT LINE (no line breaks):
####
# 66.135.144.9 www.example.com - [31/Mar/2003:23:53:57 -0800] "GET /News/index.html HTTP/1.0" 200 23725 "http://www.example.com/Multimedia/index.html" "Mozilla/4.0 (compatible; MSIE 6.0; Windows 98; Win 9x 4.90)" US WA CTL0000B400D2C90E413F5294CBD888C2E5
####
#
# TODO: use some loop logic to cut down on the mass of nearly-identical lines
# slurp in OS and user-agent values from another file?

use FileHandle;
use POSIX;
use Compress::Zlib;

die "usage: $0 <gzipped_access_logs>\n" unless @ARGV;
my @files = @ARGV;

# initialize our counters!
my ($bot, $bsd, $lin, $mac, $win, $other, $total) = 0;
my ($opbsd, $konqbsd, $galbsd, $net6bsd, $net7bsd, $fire6bsd, $fire7bsd, $fire8bsd, $net4bsd, $mozbsd, $bsdother) = 0;
my ($opnix, $konqnix, $galnix, $net6nix, $net7nix, $fire6nix, $fire7nix, $fire8nix, $moznix, $linother) = 0;
my ($opmac, $safari, $ie4mac, $ie5mac, $net4mac, $net6mac, $net7mac, $fire7mac, $fire8mac, $mozmac, $macother) = 0;
my ($opwin, $ie4win, $ie5win, $ie6win, $net4win, $net6win, $net7win, $fire6win, $fire7win, $fire8win, $mozwin, $winother) = 0;

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

    # skip entries from bots
    $total++;
    if ($agent =~ /bot|crawler/i) { $bot++; next; }

    elsif ($agent =~ /BSD/) {
      $bsd++;
      if    ($agent =~ /Opera/) { $opbsd++; next; }
      elsif ($agent =~ /Konqueror/) { $konqbsd++; next; }
      elsif ($agent =~ /Galeon/) { $galbsd++; next; }
      elsif ($agent =~ /Netscape\/6/) { $net6bsd++; next; }
      elsif ($agent =~ /Netscape\/7/) { $net7bsd++; next; }
      elsif ($agent =~ /Firebird\/0.6/) { $fire6bsd++; next; }
      elsif ($agent =~ /Firebird\/0.7/) { $fire7bsd++; next; }
      elsif ($agent =~ /Firefox\/0.8/) { $fire8bsd++; next; }
      elsif ($agent =~ /Mozilla\/4/) { $net4bsd++; next; }
      elsif ($agent =~ /Mozilla/) { $mozbsd++; next; }
      else { $bsdother++; next; } # skip other user-agents
    }

    elsif ($agent =~ /Linux/) {
      $lin++;
      if    ($agent =~ /Opera/) { $opnix++; next; }
      elsif ($agent =~ /Konqueror/) { $konqnix++; next; }
      elsif ($agent =~ /Galeon/) { $galnix++; next; }
      elsif ($agent =~ /Netscape\/6/) { $net6nix++; next; }
      elsif ($agent =~ /Netscape\/7/) { $net7nix++; next; }
      elsif ($agent =~ /Firebird\/0.6/) { $fire6nix++; next; }
      elsif ($agent =~ /Firebird\/0.7/) { $fire7nix++; next; }
      elsif ($agent =~ /Firefox\/0.8/) { $fire8nix++; next; }
      elsif ($agent =~ /Mozilla/) { $moznix++; next; }
      else { $linother++; next; } # skip other user-agents
    }

    elsif ($agent =~ /Mac/) {
      $mac++;
      if    ($agent =~ /Opera/) { $opmac++; next; }
      elsif ($agent =~ /Safari/) { $safari++; next; }
      elsif ($agent =~ /MSIE 4/) { $ie4mac++; next; }
      elsif ($agent =~ /MSIE 5/) { $ie5mac++; next; }
      elsif ($agent =~ /Camino\/0.7/) { $fire7mac++; next; }
      elsif ($agent =~ /Firefox\/0.8/) { $fire8mac++; next; }
      elsif ($agent =~ /Mozilla\/4/) { $net4mac++; next; }
      elsif ($agent =~ /Netscape6/) { $net6mac++; next; }
      elsif ($agent =~ /Netscape\/7/) { $net7mac++; next; }
      elsif ($agent =~ /Mozilla/) { $mozmac++; next; }
      else { $macother++; next; } # skip other user-agents
    }  

    elsif ($agent =~ /Windows/) {
      $win++;
      if    ($agent =~ /Opera/) { $opwin++; next; }
      elsif ($agent =~ /MSIE 4/) { $ie4win++; next; }
      elsif ($agent =~ /MSIE 5/) { $ie5win++; next; }
      elsif ($agent =~ /MSIE 6/) { $ie6win++; next; }
      elsif ($agent =~ /Mozilla\/4/) { $net4win++; next; }
      elsif ($agent =~ /Netscape6/) { $net6win++; next; }
      elsif ($agent =~ /Netscape\/7/) { $net7win++; next; }
      elsif ($agent =~ /Firebird\/0.6/) { $fire6win++; next; }
      elsif ($agent =~ /Firebird\/0.7/) { $fire7win++; next; }
      elsif ($agent =~ /Firefox\/0.8/) { $fire8win++; next; }
      elsif ($agent =~ /Mozilla/) { $mozwin++; next; }
      else { $winother++; next; } # skip other user-agents
    }

    # skip other OSes (for now)
    else { $other++; next; }

  } # end while loop
  $gz->gzclose;
} # end foreach loop


print "User-agent report:\n";
print "==================\n\n";
printf ("Bots/Crawlers (Google, etc.): $bot (%.3f%%)\n", ($bot / $total) * 100);
printf "*BSD: $bsd (%.3f%%)\n", ($bsd / $total) * 100;
printf "  Opera: $opbsd (%.3f%%)\n", ($opbsd / $total) * 100;
printf "  Konqueror: $konqbsd (%.3f%%)\n", ($konqbsd / $total) * 100;
printf "  Galeon: $galbsd (%.3f%%)\n", ($galbsd / $total) * 100;
printf "  Netscape 6: $net6bsd (%.3f%%)\n", ($net6bsd / $total) * 100;
printf "  Netscape 7: $net7bsd (%.3f%%)\n", ($net7bsd / $total) * 100;
printf "  Firebird 0.6: $fire6bsd (%.3f%%)\n", ($fire6bsd / $total) * 100;
printf "  Firebird 0.7: $fire7bsd (%.3f%%)\n", ($fire7bsd / $total) * 100;
printf "  Firefox 0.8: $fire8bsd (%.3f%%)\n", ($fire8bsd / $total) * 100;
printf "  Mozilla (Gecko/other): $mozbsd (%.3f%%)\n", ($mozbsd / $total) * 100;
printf "  other BSD user-agents: $bsdother (%.3f%%)\n\n", ($bsdother / $total) * 100;
printf "Linux: $lin (%.3f%%)\n", ($lin / $total) * 100;
printf "  Opera: $opnix (%.3f%%)\n", ($opnix / $total) * 100;
printf "  Konqueror: $konqnix (%.3f%%)\n", ($konqnix / $total) * 100;
printf "  Galeon: $galnix (%.3f%%)\n", ($galnix / $total) * 100;
printf "  Netscape 6: $net6nix (%.3f%%)\n", ($net6nix / $total) * 100;
printf "  Netscape 7: $net7nix (%.3f%%)\n", ($net7nix / $total) * 100;
printf "  Firebird 0.6: $fire6nix (%.3f%%)\n", ($fire6nix / $total) * 100;
printf "  Firebird 0.7: $fire7nix (%.3f%%)\n", ($fire7nix / $total) * 100;
printf "  Firefox 0.8: $fire8nix (%.3f%%)\n", ($fire8nix / $total) * 100;
printf "  Mozilla (Gecko/other): $moznix (%.3f%%)\n", ($moznix / $total) * 100;
printf "  other Linux user-agents: $linother (%.3f%%)\n\n", ($linother / $total) * 100;
printf "MacOS: $mac (%.3f%%)\n", ($mac / $total) * 100;
printf "  Opera: $opmac (%.3f%%)\n", ($opmac / $total) * 100;
printf "  Safari: $safari (%.3f%%)\n", ($safari / $total) * 100;
printf "  MSIE 4: $ie4mac (%.3f%%)\n", ($ie4mac / $total) * 100;
printf "  MSIE 5: $ie5mac (%.3f%%)\n", ($ie5mac / $total) * 100;
printf "  Netscape 4: $net4mac (%.3f%%)\n", ($net4mac / $total) * 100;
printf "  Netscape 6: $net6mac (%.3f%%)\n", ($net6mac / $total) * 100;
printf "  Netscape 7: $net7mac (%.3f%%)\n", ($net7mac / $total) * 100;
printf "  Firebird 0.7 (Camino): $fire7mac (%.3f%%)\n", ($fire7mac / $total) * 100;
printf "  Firefox 0.8: $fire8mac (%.3f%%)\n", ($fire8mac / $total) * 100;
printf "  Mozilla (Gecko/other): $mozmac (%.3f%%)\n", ($mozmac / $total) * 100;
printf "  other MacOS user-agents: $macother (%.3f%%)\n\n", ($macother / $total) * 100;
printf "Windows: $win (%.3f%%)\n", ($win / $total) * 100;
printf "  Opera: $opwin (%.3f%%)\n", ($opwin / $total) * 100;
printf "  MSIE 4: $ie4win (%.3f%%)\n", ($ie4win / $total) * 100;
printf "  MSIE 5: $ie5win (%.3f%%)\n", ($ie5win / $total) * 100;
printf "  MSIE 6: $ie6win (%.3f%%)\n", ($ie6win / $total) * 100;
printf "  Netscape 4: $net4win (%.3f%%)\n", ($net4win / $total) * 100;
printf "  Netscape 6: $net6win (%.3f%%)\n", ($net6win / $total) * 100;
printf "  Netscape 7: $net7win (%.3f%%)\n", ($net7win / $total) * 100;
printf "  Firebird 0.6: $fire6win (%.3f%%)\n", ($fire6win / $total) * 100;
printf "  Firebird 0.7: $fire7win (%.3f%%)\n", ($fire7win / $total) * 100;
printf "  Firefox 0.8: $fire8win (%.3f%%)\n", ($fire8win / $total) * 100;
printf "  Mozilla (Gecko/other): $mozwin (%.3f%%)\n", ($mozwin / $total) * 100;
printf "  other Windows user-agents: $winother (%.3f%%)\n\n", ($winother / $total) * 100;
printf "Other OS: $other (%.3f%%)\n\n", ($other / $total) * 100;
print "=========\n";
print "TOTAL: $total\n";

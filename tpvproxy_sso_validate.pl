#!/usr/bin/perl -w
#=============================================================================
# based on an internal cert validation tool; simplified by sfrancis
#
# verify connectivity to a list of SSO URLs: run once on all legacy webservers
# (use dsh) and once on tpvproxy1[ab] and note any discrepancies in output
# between the two. Should confirm that all TPV SSOs behave identically when
# accessed via tpvproxy1[ab] as via legacy w? webservers.
#=============================================================================

use strict;
use Sys::Hostname;

open (LIST, "tpvReport_sorted.txt") || die "can't open tpvReport_sorted.txt: $!\n";
my $i=0;
my $server=hostname();
mkdir ("output/$server", 0755);
my $cert="web.crt";
my $key="web.key";
my $openssl="LD_LIBRARY_PATH=/opt/splunk/lib /usr/bin/openssl s_client";
# really old s_client installs - like we have on tpvproxy1[ab] - don't grok "-pass"
my $openssl_opts="-ign_eof -bugs -cert $cert -key $key -pass file:pass";

while (my $line = <LIST>) {

  chomp $line;
  my ($tpvlist, $url) = split(/ /, $line);
  my ($tpvhost, $port, $uri) = split(/,/, $url);
  my $sanitized_uri = $uri;
  $sanitized_uri =~ s#/#_#g;
  my @tpvs = split(/,/, $tpvlist);

  foreach my $tpv (@tpvs) {
    $i++;
    print "$i TPV: $tpv, to $tpvhost:$port at $uri\n";
    open(TEST, ">output/$server/$tpv-$tpvhost-$port-$sanitized_uri.out") || die "couldn't open output/$server/$tpv-$tpvhost-$port-$sanitized_uri: $!\n";
    print TEST "echo \"GET $uri HTTP/1.0\\n\\n\" | $openssl $openssl_opts -connect $tpvhost:$port 2>&1\n";
    print TEST `echo "GET $uri HTTP/1.0\n\n" | $openssl $openssl_opts -connect $tpvhost:$port 2>&1`;
    close(TEST);
  }
}

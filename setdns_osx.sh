#!/bin/sh
#	$Id: setdns_osx.sh,v 1.1 2008/04/17 15:29:42 sfrancis Exp $

# use scutil(8) to set/modify our domain and nameserver info, since
# OS X ignores /etc/resolv.conf. Based on a script posted by Stephan Oeste
# <stephan@oeste.de> as a comment to
# http://www.macosxhints.com/article.php?story=20050621051643993
# useful when a remote DHCP or VPN server hands out nameservers you'd rather
# not use.

[ `id -u` == 0 ] || { echo "got root?"; exit 1; }
[ $# -ge 3 ] || { echo "usage: $0 <domain> <nameserver> <nameserver> [search_domain search_domain]"; exit 1; }

PRISVC=$( (scutil | grep PrimaryService | sed 's/.*PrimaryService : //')<< EOF
open
get State:/Network/Global/IPv4
d.show
quit
EOF
)

scutil << EOF
open
d.init
d.add ServerAddresses $2 $3
d.add DomainName $1
d.add SearchDomains $1 $4 $5
set State:/Network/Service/$PRISVC/DNS
quit
EOF

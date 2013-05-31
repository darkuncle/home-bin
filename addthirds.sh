#!/bin/sh
#
# addthirds.sh: add new ServerAlias entries (third-level domains) to all
# existing VirtualHosts in a specified Apache config file.
#
# Change this:
##   ServerAlias	city.example1.com www.city.example1.com
# to this:
##   ServerAlias	city.example2.net www.city.example2.net
##   ServerAlias	city.example1.com www.city.example1.com
#
# useful primarily for examples of advanced sed syntax.

[ $1 ] || { echo "usage: $0 <filename>" ; exit 1 ; }

FILE=$1
TMPFILE=/tmp/$FILE.$$

sed -e '/example1/{
  h
  s/ServerAlias	\(.*\)\.example1\.com .*$/ServerAlias	\1.example2.net www.\1.example2.net/
  p
  x
}' <$FILE >$TMPFILE && cat $TMPFILE >$FILE && rm $TMPFILE

exit 0

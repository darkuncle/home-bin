#!/bin/sh

# import_zones.sh: import zones into DNS
# useful when importing zones from e.g. a newly-acquired company into our
# nameservers. As with any script run as root ... BACKUP YOUR FILES FIRST!!

#######
#######
## NOTE: the sed matches and replacements in STAGE 3 _WILL_NEED_TO_BE_MODIFIED_
## to fit the syntax of the zones you're importing! Do not attempt to run
## this script with its current STAGE 3 values or it may fail in various ways.
#######
#######

#############
# VARIABLES #
#############
#
# The following variables are assigned in STAGE 1:
#
# $ZONEDIR must contain nothing but zonefiles with filenames of the form "db.example.com"
# $DEBUG: set to 1 to enable debugging output and dry-run mode (no changes will be made
#   to live named.conf, no zones added to live $NAMEDZONEDIR)
# $NAMEDCONF is the config file that new zones will be added to (should not need to be changed)
# $NAMEDZONEDIR should be set to wherever the finished zonefiles will live
#   (usually /chroot/named/master/zones, but you may want to specify a subdir
#   for easy differentiation of newly-imported zones and pre-existing zones)
# $SERIAL is (by default) set to today's date followed by 00 (YYYYMMDD00)
# $AUTH: normally set to master; set to slave if you want to transfer zones
#   from elsewhere. If set to slave, stages 2 and 3 are skipped since the zones
#   will transfer from the SOA(s), the IP(s) of which you will be prompted for ($MASTERS).
# $TTLVAL: zone or record timeout value in seconds; defaults to 86400 seconds (24 hours)
# $MX1,$MX2: mailservers used in MX record settings
#
# NOTE: $TTLVAL and $MX1,MX2 are optional parts of STAGE 3. Use with caution.
#############

#########
# USAGE #
#########
[ $1 ] || { echo "usage: $0 /path/to/zonefiles/" 1>&2 ; exit 1; }
echo
echo "######"
echo "DO NOT attempt to run this script without modifying the sed match/replace"
echo "syntax in STAGE 3 to fit the syntax of the zones you're importing!"
echo "######"
echo
echo -n "Press Q to go edit the source (any other key to continue): "
read ANYKEY
case $ANYKEY in
  [Qq]*) echo "exiting ..."
         exit 0 ;;
      *) echo "" ;;
esac

####################
# STAGE 0: cleanup #
####################
cleanup() {
echo ""
echo -n "CLEANING UP: reexample2 $TMPZONEDIR, $ZONELIST ... "
rm -r $TMPZONEDIR $ZONELIST && echo "done." || echo "FAILED!"
[ $DEBUG = 1 ] && echo "Don't forget to delete $NAMEDCONF and $NAMEDZONEDIR."
return 0
}

##################
# STAGE 1: setup #
##################
echo "STAGE 1: setup ... "
ZONEDIR=$1
DEBUG=1					# set to 1 to enable debugging output and dry-run mode
if [ $DEBUG = 1 ] ; then		# debug mode; don't edit live configs
  NAMEDCONF=`mktemp -t namedconf`
  NAMEDZONEDIR=`mktemp -d -t namedzonedir`
else					# THESE SHOULD REFLECT YOUR LAYOUT!
  NAMEDCONF=/chroot/named/etc/named.conf
  NAMEDZONEDIR=/chroot/named/master/zones/example2.com
fi
ZONELIST=`mktemp -t zones`
TMPZONEDIR=`mktemp -d -t zonedir`
SERIAL=`/bin/date +%Y%m%d`00		# e.g. 2006070700
AUTH=slave				# set to "slave" or "master"
TTLVAL=86400				# OPTIONAL
MX1='smtp01.example.com.'		# OPTIONAL
MX2='smtp02.example.com.'		# OPTIONAL

if [ $DEBUG = 0 ] ; then
  [ `id -u` = 0 ] || { echo "got root?" 1>&2; cleanup; exit 1; }
fi
[ -d $ZONEDIR ] || { echo "$ZONEDIR is not a directory!" 1>&2; cleanup; exit 1; }
DIRSTUFF=`/bin/ls $ZONEDIR`
[ -z "$DIRSTUFF" ] && { echo "$ZONEDIR is empty!" 1>&2; cleanup; exit 1; }

if [ $AUTH = slave ] ; then
  echo ""
  echo "\$AUTH set to slave; enter the IP(s) of the master(s) for these zones."
  echo "For multiple masters, enter a semi-colon-delimited list of IPs (e.g. \"1.2.3.4; 5.6.7.8\")"
  echo -n "(enter q to quit): "
  read MASTERS
  case $MASTERS in
    [Qq]*) echo "exiting ..."
           cleanup
           exit 0
           ;;
        *) ;;
  esac
fi

if [ $NAMEDZONEDIR = /chroot/named/master/zones ] ; then
  ZONEPRE=zones
else
  ZONEPRE=zones/`basename $NAMEDZONEDIR`
fi

for i in `/bin/ls $ZONEDIR`; do basename $i; done >>$ZONELIST
ZONES=`cut -c4- $ZONELIST`

if [ $DEBUG = 1 ] ; then
  echo "DEBUG = 1, BEGINNING VARIABLE DUMP:"
  echo "  ZONEDIR: $ZONEDIR"
  echo "  NAMEDCONF: $NAMEDCONF"
  echo "  NAMEDZONEDIR: $NAMEDZONEDIR"
#  echo "  ZONELIST: " && cat $ZONELIST
  echo "  SERIAL: $SERIAL"
  echo "  AUTH: $AUTH"
  echo "  MASTERS: $MASTERS"
  echo "  ZONEPRE: $ZONEPRE"
#  echo "  ZONES: $ZONES"
  echo "VARIABLE DUMP COMPLETE (press any key to continue)"
  read ANYKEY
fi

cd $ZONEDIR
echo "STAGE 1 COMPLETE."
echo ""

####################################
# STAGE 2: add zones to named.conf #
####################################
echo "STAGE 2: adding zones to named.conf ... "

if [ $AUTH = slave ] ; then
  for ZONE in $ZONES
  do
    grep $ZONE $NAMEDCONF && echo "  $ZONE present in $NAMEDCONF; skipping ... " ||\
    echo $ZONE | sed "s:$ZONE:zone \"$ZONE\" {\\
	type $AUTH;\\
	file \"$ZONEPRE/db.$ZONE\";\\
	masters { $MASTERS; };\\
};\\
:"
  done >>$NAMEDCONF && echo "STAGE 2 COMPLETE." || { echo "FAILED!" 1>&2; exit 1; }
  cleanup
else
  for ZONE in $ZONES
  do
    grep $ZONE $NAMEDCONF && echo "  $ZONE present in $NAMEDCONF; skipping ... " ||\
    echo $ZONE | sed "s:$ZONE:zone \"$ZONE\" {\\
	type $AUTH;\\
	file \"$ZONEPRE/db.$ZONE\";\\
};\\
:"
  done >>$NAMEDCONF && echo "STAGE 2 COMPLETE." || { echo "FAILED!" 1>&2; exit 1; }
fi

###########################
# STAGE 3: edit zone info #
###########################
if [ $AUTH = master ] ; then
  echo "STAGE 3: setting serial ($SERIAL), SOA and NS for all zones ... "
  for ZONE in $ZONES
  do
    TMPZONE=`mktemp -t $ZONE`
    ######
    # suck in zonefile and set serial, SOA, NS, remove $ORIGIN
    # optional: set TTL, MX
    ######
    sed "s/.*; serial$/				$SERIAL ; serial/" <db.$ZONE |\
    sed 's/.*IN SOA	ns1\.example3\.com\. dns\.example3\.com\. ($/@			IN SOA atlas.example.com. hostmaster.example.com. (/' |\
    sed '/^\$ORIGIN.*$/d' |\
    sed '/.*NS	ns1\.example3\.com\.$/d' |\
    sed 's/.*NS	ns2\.example3\.com\.$/\
			NS	atlas.example.com.\
			NS	pan.example.com.\
			NS	rhea.example.com.\
			NS	titan.example.com.\
\
/' >$TMPZONE

    # optional bits - USE WITH CAUTION! (replace '>$TMPZONE' with '|\' on previous line):
    #    sed "s/^\$TTL.*/\$TTL $TTLVAL/" |\
    #    sed "s/.*mailsorter\.in.*/			MX	10	$MX1/" |\
    #    sed "s/.*mailsorter\.ma.*/			MX	20	$MX2/" >$TMPZONE

    echo -n "  importing $ZONE into $NAMEDZONEDIR ... "
    cp $TMPZONE $NAMEDZONEDIR/db.$ZONE && rm $TMPZONE && echo "done." || { echo "FAILED!" 1>&2; exit 1; }
  done && echo "STAGE 3 COMPLETE.\n" || { echo "FAILED!" 1>&2; exit 1; }
  cleanup
  [ $DEBUG = 0 ] && { echo; echo "Don't forget to restart named!"; echo; }
fi


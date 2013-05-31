#!/bin/sh
#	$Id: resurrect_dynamo.sh,v 1.20 2007/12/04 04:50:35 sfrancis Exp $
#
# our craptacular app server (ATG dynamo) has a habit of dying on a regular
# basis, drp by drp, until all the sites it serves (example.com, example2.com,
# etc.) drop offline. This script's purpose is to run from cron periodically
# and pre-emptively locate dead DRPs and resurrect them. It is of course
# long since past the time that we should have migrated to an app server that's
# 1) supported;
# 2) stable;
# 3) platform agnostic (also not tied to an IP address);
# 4) up-to-date;
# 5) (and optionally) free
#
# like, say, tomcat.

PGREP="/usr/bin/pgrep -f"
PKILL="/usr/bin/pkill -9 -f"
# be quiet and don't actually download anything; we just want exit status
WGET="/opt/csw/bin/wget -q --spider"
# this is weak sauce - there ought to be a cleaner way to determine which
# app server we're on (can't use hostname or primary IP anymore, and not
# all of them have the same secondary NIC)
SERVER=`hostname | cut -d'.' -f1 | cut -c6,7,8,11`
IP=`grep $SERVER /etc/hosts | grep '10.0' | awk '{print $1}'`
DRPS="drp01 drp02 drp03 drp04"
LOG=/aa/logs/dynamo/resurrect.log

for DRP in $DRPS
do
  # figuring $PORT this way is kinda hokey, but quicker than a big
  # case structure (which is unnecessarily lengthy)
  NUM=`echo $DRP | cut -c5`
  PORT=885${NUM}
  TARGET="${SERVER}drp${NUM}"
  URL="http://www.example.com/myapp/?dyn_server=${IP}:${PORT}%20TARGET=${TARGET}"
  $WGET $URL && sleep 5 || {
    echo "`/usr/bin/date '+%Y%m%d %H:%M:%S'` $TARGET unresponsive - resurrecting ... " >>$LOG
    DRPPID=`$PGREP $DRP` && {
    $PKILL -P $DRPPID >>$LOG 2>&1 && echo "  killed child java process of $DRP" >>$LOG \
     || echo "  error killing child java process of $DRP." >>$LOG
    } || echo "  no child processes for $DRP." >>$LOG
    $PKILL $DRP >>$LOG 2>&1 && echo "  killed $DRP." >>$LOG || echo "  error killing $DRP." >>$LOG
    sleep 10
    /etc/init.d/dyn-server $DRP start >/dev/null 2>&1 && echo "  started $DRP." >>$LOG
    echo >>$LOG
  }
  sleep 20
done

exit 0

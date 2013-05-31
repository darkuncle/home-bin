#!/bin/sh
#
# grab memory usage stats for UID web (Apache & CGIs) on an ongoing basis

[ $1 ] || { echo "usage: $0 [BURNIN|PROD1|PROD2]"; exit 1; }
FARM=$1

case $FARM in

  "BURNIN")
    SERVERS="wf1-4 wf1-5 wf1-6"
    OUTFILE=memory_usage.burnin
  ;;

  "PROD1")
    SERVERS="wf1-8 wf1-9 wf1-10"
    OUTFILE=memory_usage.prod1
  ;;

  *)
    echo "currently supported farms: BURNIN PROD1"
    exit 1
  ;;

esac

while true; do
  date >> $OUTFILE
  for SERVER in $SERVERS; do
    ssh -qn $SERVER "hostname; uptime; svmon -U web -O unit=MB|tail -1" >> $OUTFILE
  done
  echo >> $OUTFILE
  sleep 900
done

exit 0

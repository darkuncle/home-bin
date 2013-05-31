#!/bin/sh


[ $1 ] || { echo "usage: $0 node_to_rebuild" ; exit 1 ; }
[ `id -u` == 0 ] || { echo "got root?" ; exit 1 ; }

# rebuild a given cassandra retargeting node (currently, to change chunk size
# from 4KB to 256KB). basically:
# pause ; reimage ; redeploy ; insert token into configs ; adjacent node snaps ;
# transfer data from adjacent nodes ; merge data ; restart ; unpause ; cleanup
#
# http://wiki.example.org/display/TECH/Cassandra+Rebuild

NODE=$1
IP=`host $NODE|awk '{print $4}'`
PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/bin:/bin:/opt/bin:/opt/sbin:/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin

# set this manually after checking /etc/hosts or /etc/cassandra/machine-info
SEED="10.33.1.33"

[ $IP == $SEED ] && { echo "$NODE ($IP) is set as the seed node for this ring. Please set a different seed node first." ; echo "see http://wiki.example.org/display/TECH/Cassandra+Rebuild for details." ; exit 1 ; }


echo ""
echo "this script should be run as root from the relevant colo's x-box."
echo "see http://wiki.example.org/display/TECH/Cassandra+Rebuild for more details."
echo ""
echo -n "rebuild $NODE ($IP)? "
read ANS
case $ANS in
  [Yy]*)
    echo ""
    continue
    ;;
  *)
    echo ""
    echo "  bailing out ..."
    exit 1
    ;;
esac


##
## setup: determine adjacent nodes and token, pause, fix nagios
##

RINGTMP=`mktemp`
ssh $NODE "cassandra-nodetool -h 127.0.0.1 -p 12352 ring" >>$RINGTMP
# if $NODE is first/last in the ring, set ADJ1/ADJ2 manually here
# until we figure out how to "wrap" around the ends of the ring
ADJ1=`grep -B1 $IP $RINGTMP|head -1|awk '{print $1}'`
ADJ2=`grep -A1 $IP $RINGTMP|tail -1|awk '{print $1}'`
TOKEN=`grep $IP $RINGTMP|awk '{print $6}'`

echo -n "pausing node in MCP ... "
ox-change-state -s paused -c "rebuilding cassandra node with 256KB chunk size" -n $NODE && echo "done." || { echo "failed - ABORTING" ; exit 1 ; }

echo -n "cleaning up nagios ... "
ssh nagios "/usr/local/bin/rm_host_from_nagios_known_hosts_hack $NODE" >/dev/null && echo "done." || { echo "failed - ABORTING" ; exit 1 ; }


##
## reimage
##

echo -n "reimaging $NODE (wait for it) ... "
ox-reimage -i ssdraid0 -c "rebuilding cassandra node with 256KB chunk size" -n $NODE || { echo "failed - ABORTING" ; exit 1 ; }
sleep 120
while true ; do
  STATUS=`ox-list-machines -c xf -f state | grep $NODE | awk '{print $2}'`
  case $STATUS in
    "paused")
      echo -n "stuck on reboot; issuing manual shutdown: "
      ssh $NODE "shutdown -r now" >/dev/null 2>&1 && echo -n "done ... " || { echo "failed to reboot $NODE - ABORTING" ; exit 1 ; }
      sleep 120
    ;;
    "imaging")
    echo -n "imaging ... "
    sleep 60
    ;;
    "imaged")
    echo "reimaging complete."
    break 
    ;;
  esac
done


##
## redeploy
##

echo -n "redeploying $NODE ... "
  ox-deploy-physical -p "retargetssd" -g orange-team -r cassandra-retarget.prod.xf mondemand.xf -e production -f ssd ssd_adata_2x256 -n $NODE && echo "done." || { echo "failed - aborting!"; exit 1 ; }

echo ""
echo "sleeping for 15 minutes to give slack a chance to run" && sleep 900
echo ""


##
## remove node's original host key from /root/.ssh/known_hosts
## set seed node IP and replace initial token
##

sed -i /$NODE/d /root/.ssh/known_hosts
echo -n "setting seed IP and initial token on $NODE ... "
  ssh -q $NODE "echo \"$SEED xtable-seed-01\" >> /etc/hosts" || { echo "failed to set seed IP - ABORTING" ; exit 1 ; }
  ssh $NODE "sed -i \"s#<InitialToken></InitialToken>#<InitialToken>$TOKEN</InitialToken>#\" /etc/cassandra/storage-conf.xml" && echo "done." || { echo "failed to set initial token - ABORTING" ; exit 1 ; }


##
## start/stop cassandra here to create the necessary dir structure; test ring
##

echo -n "testing ring placement of $NODE ... "
  ssh $NODE "service cassandra start >/dev/null" || { echo "failed to start cassandra on $NODE - ABORTING" ; exit 1; }
  sleep 120
  ssh $NODE "cassandra-nodetool -h 127.0.0.1 -p 12352 ring|grep -q $TOKEN" || { echo "original token not found in latest ring listing! please investigate - ABORTING" ; exit 1 ; }
  ssh $NODE "service cassandra stop >/dev/null" && echo "done." || { echo "failed to stop cassandra on $NODE - ABORTING" ; exit 1 ; }

echo -n "creating snapshots on adjacent nodes $ADJ1 and $ADJ2 ... "
  ssh -q $ADJ1 "cassandra-nodetool -h 127.0.0.1 -p 12352 snapshot" || { echo "failed to snap on $ADJ1 - ABORTING" ; exit 1 ; }
  ssh -q $ADJ2 "cassandra-nodetool -h 127.0.0.1 -p 12352 snapshot" && echo "done." || { echo "failed to snap on $ADJ2 - ABORTING" ; exit 1 ; }


##
## transfer snapshots from adjacent nodes
##

  ADJ1SNAP=`ssh $ADJ1 "cd /mnt/cassandra/data/retarget/snapshots && find . -depth -type d | head -1 | xargs basename"`
  ADJ2SNAP=`ssh $ADJ2 "cd /mnt/cassandra/data/retarget/snapshots && find . -depth -type d | head -1 | xargs basename"`

echo "transferring snapshots (this will take quite a while): "

  echo -n "  starting listeners: "
  ssh -f $NODE "cd /mnt/cassandra/data/retarget && nc -ld 7000 | tar xf - &" && echo -n "$NODE:7000 " || { echo "failed to start port 7000 listener - ABORTING" ; exit 1 ; }
  ssh -f $NODE "cd /mnt/cassandra/data/retarget && nc -ld 7001 | tar xf - &" && echo "$NODE:7001" || { echo "failed to start port 7001 listener - ABORTING" ; exit 1 ; }

  echo -n "  starting transfers: "
  ssh -f $ADJ1 "cd /mnt/cassandra/data/retarget/snapshots && tar cf - $ADJ1SNAP | nc $NODE 7000 &" && echo -n "$ADJ1:7000 " || { echo "failed transfer from ADJ1 ($ADJ1) - ABORTING" ; exit 1 ; }
  ssh -f $ADJ2 "cd /mnt/cassandra/data/retarget/snapshots && tar cf - $ADJ2SNAP | nc $NODE 7001 &" && echo "$ADJ2:7001" || { echo "failed transfer from ADJ2 ($ADJ2) - ABORTING" ; exit 1 ; }

  echo -n "  copying ... "
  while true ; do
    ssh $NODE "pgrep -fl 'nc -ld 700'" >/dev/null && { echo -n "copying ... " ; sleep 300 ; } || { echo "done." ; break ; }
  done


##
## merge snapshots
##

echo -n "merging snapshots on $NODE ... "
  ssh $NODE "cd /mnt/cassandra/data/retarget && mv $ADJ1SNAP/* . && rmdir $ADJ1SNAP" || { echo "failed to move files from $ADJ1SNAP - ABORTING" ; exit 1 ; }
  ssh -t $NODE "cd /mnt/cassandra/data/retarget && mv -i $ADJ2SNAP/* . && rmdir $ADJ2SNAP" && echo "done." || { echo "" ; echo "WARNING: failed to merge files from $ADJ2SNAP; likely filename collision with files from $ADJ1SNAP." ; echo -n "please complete step 12b from the wiki manually, then hit <enter> to continue: " ; read ANS1 ; }


##
## cleanup: start cassandra, remove snaps, unpause, compact
##

echo ""
echo -n "starting cassandra on $NODE (wait for it) ... "
  ssh $NODE "chown -R cassandra:cassandra /mnt/cassandra/data" || { echo "failed to set ownership on /mnt/cassandra/data - ABORTING" ; exit 1 ; }
  ssh $NODE "service cassandra start && sleep 300" >/dev/null && echo "done." || { echo "cassandra did not start on $NODE - please investigate. ABORTING" ; exit 1 ; }

echo -n "cleaning up snapshots on adjacent nodes ... "
  ssh $ADJ1 "rm -r /mnt/cassandra/data/{retarget,system}/snapshots/*" || { echo "failed to clean up snaps on $ADJ1 - ABORTING" ; exit 1 ; }
  ssh $ADJ2 "rm -r /mnt/cassandra/data/{retarget,system}/snapshots/*" && echo "done." || { echo "failed to clean up snaps on $ADJ2 - ABORTING" ; exit 1 ; }

echo -n "unpausing $NODE ... "
  ox-change-state -s running -c "rebuild complete for 256KB RAID chunk size" -n $NODE && echo "done." || { echo "failed to unpause $NODE - ABORTING" ; exit 1 ; }

echo -n "starting compaction on $NODE ... "
  ssh $NODE "cassandra-nodetool -h 127.0.0.1 -p 12352 cleanup" && echo "started." || { echo "failed to initiate compaction on $NODE - please investigate. ABORTING" ; exit 1 ; }


##
## all done
##

rm $RINGTMP
echo "rebuild of $NODE complete."
exit 0

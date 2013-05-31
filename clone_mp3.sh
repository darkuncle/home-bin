#!/bin/sh

[ $1 ] || { echo "usage: $0 /Users/Shared/mp3z/path/to/item/" ; exit 1 ; }
LOCAL=/Users/Shared/mp3z
DEST1=/Volumes/monolith/mp3z
DEST2=/Volumes/LOLVIDZ/mp3z
DEST3=paranor:/var/www/storage/mp3z
RSYNC=/usr/bin/rsync
RSYNC_OPTS="-av --progress --size-only"
ITEM=`echo $1|cut -d'/' -f5-`

for DEST in $DEST1 $DEST2 $DEST3
do
  $RSYNC $RSYNC_OPTS $LOCAL/$ITEM $DEST/$ITEM
done

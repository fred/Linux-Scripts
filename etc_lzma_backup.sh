#!/bin/sh 

if [ -f "/DISKFULL" ]
then
  echo "Disk if full. Aborting Backup"
  exit 1
fi

NICE="18"

# Backup Dest directory, change this if you have someother location
DEST="/backup/local"
 
# Main directory where backup will be stored
MBD="$DEST/etc/compressed_weekly/"
  
# Get data in dd-mm-yyyy format
NOW="$(date +"%Y%m%d_%H%M%S")"
SUFFIX="etc.tar.lzma"

[ ! -d $MBD ] && mkdir -p $MBD || :

nice -n $NICE tar cvf - /etc/ | nice -n $NICE lzma -2 -z -k -c > "$MBD/${NOW}_${SUFFIX}"

chmod 755 "$MBD/${NOW}_${SUFFIX}"

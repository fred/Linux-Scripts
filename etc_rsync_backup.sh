#!/bin/bash
# ----------------------------------------------------------------------
# mikes handy rotating-filesystem-snapshot utility
# ----------------------------------------------------------------------
# this needs to be a lot more general, but the basic idea is it makes
# rotating backup-snapshots of /home whenever called
# ----------------------------------------------------------------------


if [ -f "/DISKFULL" ]
then
  echo "Disk if full. Aborting Backup"
  exit 1
fi

# ------------- system commands used by this script --------------------
ID=/usr/bin/id
ECHO=/bin/echo
MOUNT=/bin/mount
RM=/bin/rm
MV=/bin/mv
CP=/bin/cp
TOUCH=/usr/bin/touch
DATE=/bin/date
RSYNC=/usr/bin/rsync

WEEK_DAY=`${DATE} "+%w"`

# ------------- file locations -----------------------------------------

SOURCE="/etc"
DESTINATION_FOLDER="/backup/local/etc"
EXCLUDES=/root/Scripts/etc_excludes.txt 


# ------------- the script itself --------------------------------------

# make sure we're running as root
#if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi


#${RSYNC}	-avz --delete --delete-excluded	\
#	      --exclude-from="${EXCLUDES}"	\
#	      $SOURCE ${DESTINATION_SERVER}:${DESTINATION_FOLDER}/${WEEK_DAY}/

${RSYNC}      -av --cvs-exclude --delete --delete-excluded \
              --exclude-from="${EXCLUDES}"      \
              ${SOURCE}/ ${DESTINATION_FOLDER}/${WEEK_DAY}/


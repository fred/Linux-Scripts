#!/bin/sh
# This method will use mysqlhotbackup utility, it's fast and locks the tables for writing.
# With mysqlhotcopy, the tables of the database being backed up are temporarily locked 
#  so no changes can be made (although data can still be read), the underlying files 
#  used by the database are copied to another physical location using O/S commands, 
#  and once the file copy is completed, the database tables are unlocked. 
# Using mysqlhotcopy can result in faster backups depending on the copy speed of the O/S 
#  and the size of the database being backed up.

WEEK_DAY=`date "+%w"`
BACKUP_FOLDER="/backup/local/mysql/hotcopy"
DB_USERNAME="root"
DB_PASSWORD=""
MYSQLHOTCOPY="/usr/bin/mysqlhotcopy --addtodest --user=${DB_USERNAME} "

DATABASES=`ls -l /var/lib/mysql/ | grep ^d | awk {'print $8'}`

for DATABASE in $DATABASES 
do
    DESTINATION_FOLDER="${BACKUP_FOLDER}/${DATABASE}/${WEEK_DAY}/"
    LOGFILE="${BACKUP_FOLDER}/${DATABASE}/backup.log"

    if [ ! -d "${DESTINATION_FOLDER}" ]; then
            mkdir -p "${DESTINATION_FOLDER}"
    fi
    echo `date` >> $LOGFILE
    echo "Starting to hotbackup of ${DATABASE} database to ${DESTINATION_FOLDER}" >> $LOGFILE
    $MYSQLHOTCOPY --debug --flushlog $DATABASE $DESTINATION_FOLDER >> $LOGFILE
done

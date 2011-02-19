#!/bin/bash

# modify the following to suit your environment
export DB_USER="root"
export DB_PASSWD=""

# Nice Level. Try to use little resources
NICE=17

# Databases to backup
DATABASES="mysql"

# Backup Dest directory, change this if you have someother location 
# Main directory where backup will be stored
BACKUP_DIR="/backup/local/mysql"

# Get data in dd-mm-yyyy format
NOW="$(date +"%Y%m%d_%H%M%S")"
DATE_FOLDER="$(date +"%Y/%m")"
FINAL_FOLDER="${BACKUP_DIR}/${DATE_FOLDER}"

mkdir -p $FINAL_FOLDER


# All databases
SQL="${FINAL_FOLDER}/all_${NOW}.sql"
nice -n $NICE /usr/bin/mysqldump -u$DB_USER -p$DB_PASSWD --all-databases > "${SQL}"
nice -n $NICE /bin/bzip2 -4 -z "${SQL}"
chmod 600 "${SQL}.bz2"

# Given databases
for DB in $DATABASES
do
    SQL="${FINAL_FOLDER}/${DB}_${NOW}.sql"
    nice -n $NICE /usr/bin/mysqldump -u$DB_USER -p$DB_PASSWD $DB > "${SQL}"
    nice -n $NICE /bin/bzip2 -4 -z "${SQL}"
    chmod 600 "${SQL}.bz2"
done

exit 0


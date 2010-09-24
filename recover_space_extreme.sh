#!/bin/sh
BACKUP_FOLDER="/backup/local"

# clear apt files
aptitude clean

# remove archived logs
/usr/bin/find /var/log/ -type f  -name "*.bz2" -exec rm -rvf {} \;
/usr/bin/find /var/log/ -type f  -name "*.gz"  -exec rm -rvf {} \;

# Delete mysql backups older than 7 days
/usr/bin/find ${BACKUP_FOLDER}/mysql/ -type f -mtime +7 -exec rm -rfv {} \;

# Clear /tmp files olders than 7 days
/usr/bin/find /tmp/ -type f -mtime +7 -exec rm -rfv {} \;

# Force a logratate 
/usr/sbin/logrotate -f /etc/logrotate.conf

# and remove archived logs again right after
/usr/bin/find /var/log/ -type f -name "*.bz2" -exec rm -rvf {} \;

# Remove older compressed backups, keep 1 month only (4 backups)
/usr/bin/find ${BACKUP_FOLDER}/etc/ -type f -name "*.lzma" -mtime +31 -exec rm -rvf {} \;


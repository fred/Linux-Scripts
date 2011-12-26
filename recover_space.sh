#!/bin/sh

# clear portage files
rm -rf /var/tmp/portage/* /var/log/portage/* /usr/portage/distfiles/*

# remove archived logs older than 31 days
/usr/bin/find /var/log/ -name "*.bz2" -mtime +31 -exec rm -rvf {} \;

# Delete mysql backups older than 31 days
/usr/bin/find /backup/mysql/ -type f -mtime +31 -exec rm -rfv {} \;

# Remove older compressed backups, keep 1 month only
/usr/bin/find /backup/etc/compressed_weekly/ -type f -mtime +31 -exec rm -rvf {} \;

# Clear /tmp files olders than 31 days
/usr/bin/find /tmp/ -type f -mtime +31 -exec rm -rfv {} \;

# Force a logratate
/usr/sbin/logrotate -f /etc/logrotate.conf


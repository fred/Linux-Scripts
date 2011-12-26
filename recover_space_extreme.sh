#!/bin/sh

# clear portage files
rm -rf /var/tmp/portage/* /var/log/portage/* /usr/portage/distfiles/*

# Remove build packages (300-500MB)
rm -rf /usr/portage/packages/*

# remove archived logs
/usr/bin/find /var/log/ -type f  -name "*.bz2" -exec rm -rvf {} \;

# Delete mysql backups older than 7 days
/usr/bin/find /backup/mysql/ -type f -mtime +7 -exec rm -rfv {} \;

# Clear /tmp files olders than 7 days
/usr/bin/find /tmp/ -type f -mtime +7 -exec rm -rfv {} \;

# Force a logratate and remove archived logs again right after
/usr/sbin/logrotate -f /etc/logrotate.conf
/usr/bin/find /var/log/ -type f -name "*.bz2" -exec rm -rvf {} \;

# Remove older compressed backups, keep 1 month only
/usr/bin/find /backup/etc/ -type f -name "*.lzma" -mtime +31 -exec rm -rvf {} \;


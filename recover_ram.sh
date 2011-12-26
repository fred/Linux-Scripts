#!/bin/sh
# This script will try to recover RAM by several methods

# 1. Restart Mysql
/etc/init.d/mysql restart

# 2. Restart Apache
/etc/init.d/apache reload

sleep 5

# 3. Flush Cache
echo 3 > /proc/sys/vm/drop_caches

sleep 5

# 4. Recover Swap
/sbin/swapoff /dev/xvdb
sleep 2
/sbin/swapon /dev/xvdb


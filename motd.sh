#!/bin/sh

MACHINE=`uname -rn`
CPUTIME=$(ps -eo pcpu | awk 'NR>1' | awk '{tot=tot+$1} END {print tot}')
CPUCORES=$(cat /proc/cpuinfo | grep -c processor)

echo "
- CPU Usage                = $CPUTIME% ($CPUCORES Cores)
- Memory free (real)       = `free -m | head -n 2 | tail -n 1 | awk {'print $4'}` Mb
- Memory free (cache)      = `free -m | head -n 3 | tail -n 1 | awk {'print $3'}` Mb
- Swap in use              = `free -m | tail -n 1 | awk {'print $3'}` Mb
- Disk Space Used          = `df -h  / | awk '{ a = $5 } END { print a }'`

`uptime`
"

SERVER_NAME=`hostname`
SEND_TO="fred"

LOGIN_WHO=`who -m | cut -d"(" -f2 | cut -d")" -f1 | tr -d \r`
CPUTIME=$(ps -eo pcpu | awk 'NR>1' | awk '{tot=tot+$1} END {print tot}')
CPUCORES=$(cat /proc/cpuinfo | grep -c processor)
MYSQL_MEMORY=`ps -C mysqld -o rss= | awk '{s+=$1}END{print s/1024}'`


echo "
 Root Login Access to ${SERVER_NAME}
 From: ${LOGIN_WHO}
 Date: `date`

Active Users:
`who`

System Summary (collected `date`)

- CPU Usage                = $CPUTIME %  ($CPUCORES Cores)
- Memory free (real)       = `free -m | head -n 2 | tail -n 1 | awk {'print $4'}` Mb
- Memory free (cache)      = `free -m | head -n 3 | tail -n 1 | awk {'print $4'}` Mb
- Swap in use              = `free -m | tail -n 1 | awk {'print $3'}` Mb
- System Uptime            =`uptime`
- Disk Space Used          = `df -h  / | awk '{ a = $5 } END { print a }'`
- MySQL RAM                = `echo $MYSQL_MEMORY` MB

" | mail -s "Alert: Root Login to ${SERVER_NAME} from ${LOGIN_WHO}" $SEND_TO


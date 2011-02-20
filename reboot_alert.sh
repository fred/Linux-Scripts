SERVER_NAME=`hostname`
SEND_TO="root"

echo "
Server ${SERVER_NAME} has rebooted.

Date: `date`

Uptime: `uptime`

Active Users:
`who`

" | mail -s "Alert: Server ${SERVER_NAME} has rebooted" $SEND_TO



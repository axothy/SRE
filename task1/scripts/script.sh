#!/bin/bash

STATUS_URL="http://localhost:8888/status"
STATUS_FILE="/opt/webapp/status.txt"
LOG_FILE="/opt/webapp/status.log"

response=$(curl -s --max-time 10 $STATUS_URL)

if [ "$response" == "Ok" ]; then
    echo "SUCCESS $(date)" > $STATUS_FILE
else
    echo "ERROR $(date)" > $STATUS_FILE
    echo "[$(date)] ERROR: Status is not 'Ok'... Response: $response" >> $LOG_FILE
fi

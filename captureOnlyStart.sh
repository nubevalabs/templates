#!/bin/bash
# Check if Moloch Capture process is running
# Put this into root crontab to run every minute (sudo crontab -e)
# * * * * * /data/moloch/captureOnlyStart.sh

SERVICE='moloch-capture'

if ps ax | grep -v grep | grep $SERVICE > /dev/null
then
    echo "$SERVICE service running, everything is fine"
else
    echo "$SERVICE is not running"
    cd /data/moloch/bin
    /bin/rm -f /data/moloch/capture.log.old
    /bin/mv /data/moloch/logs/capture.log /data/moloch/logs/capture.log.old
    /data/moloch/bin/moloch-capture -c /data/moloch/etc/config.ini > /data/moloch/logs/capture.log 2>&1 &
fi

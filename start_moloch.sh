#!/bin/bash
cd /data/moloch/bin
/bin/rm -f /data/moloch/capture.log.old
/bin/mv /data/moloch/logs/capture.log /data/moloch/logs/capture.log.old
/data/moloch/bin/moloch-capture -c /data/moloch/etc/config.ini > /data/moloch/logs/capture.log 2>&1 &
sleep 25
# Start moloch viewer process
cd /data/moloch/viewer
/bin/rm -f /data/moloch/logs/viewer.log.old
/bin/mv /data/moloch/logs/viewer.log /data/moloch/logs/viewer.log.old
export NODE_ENV=production
exec /data/moloch/bin/node /data/moloch/viewer/viewer.js -c /data/moloch/etc/config.ini > /data/moloch/logs/viewer.log 2>&1 &

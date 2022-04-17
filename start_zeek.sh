#!/bin/bash
cd /opt/zeek/logs
/opt/zeek/bin/zeek -i nurx0 > output.log 2>&1 &

#!/bin/bash
 exec 100>/var/tmp/testlock.lock || exit 1
 flock -w 10 100 || exit 1

 echo "Doing some stuff…"
 echo "Lock file for 10 seconds…"
# sleep 5

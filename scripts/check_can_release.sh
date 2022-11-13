#!/bin/sh

source ./values.env

min_release_time=`expr $GENESIS_TIMESTAMP - 86400`
if [ $(date +%s) -gt $min_release_time ]; then
  echo "true"
else
  echo "false"
fi

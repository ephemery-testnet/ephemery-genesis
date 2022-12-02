#!/bin/sh

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
source ./values.env

next_iteration_number=$(expr $ITERATION_NUMBER + 1)
next_chainid=$(expr $CHAIN_ID + 1)
next_genesis_time=$(expr $GENESIS_TIMESTAMP + $GENESIS_INTERVAL)

echo "New CHAIN_ID: $next_chainid"
echo "New GENESIS_TIMESTAMP: $next_genesis_time"

cat ./values.env | while read line ; do
  line=`echo $line | sed 's/ ITERATION_NUMBER=".*"/ ITERATION_NUMBER="'"$next_iteration_number"'"/'`
  line=`echo $line | sed 's/ CHAIN_ID=".*"/ CHAIN_ID="'"$next_chainid"'"/'`
  line=`echo $line | sed 's/ GENESIS_TIMESTAMP=".*"/ GENESIS_TIMESTAMP="'"$next_genesis_time"'"/'`
   
  # increment all fields that match *_FORK_VERSION
  #fv_field=`echo $line | sed 's/^\(.* \([^ ]*_FORK_VERSION\).*\|.*\)$/\2/'`
  #if [ $fv_field ]; then
  #  fv_value=$(eval "echo \$$fv_field")
  #  fv_value=`printf "%d" $fv_value`
  #  
  #  fv_next_value=`echo "0x$(printf '%x\n' $(expr $fv_value + 1))"`
  #  echo "New $fv_field: $fv_next_value"
  #  
  #  line=`echo $line | sed 's/ '"$fv_field"'=".*"/ '"$fv_field"'="'"$fv_next_value"'"/'`
  #fi
   
  echo $line >> $tmp_dir/values.env
done

mv $tmp_dir/values.env ./values.env
cat ./values.env

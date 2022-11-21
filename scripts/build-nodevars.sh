#!/bin/bash -e
set -x

source ./values.env
echo 'ITERATION_NUMBER="'"$ITERATION_NUMBER"'"' >> ./dist/nodevars_env.txt
echo 'CHAIN_ID="'"$CHAIN_ID"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENR="'"$(cat ./dist/bootstrap_nodes.txt | sed -E '/^$/d' | head -n1)"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENR_LIST="'"$(cat ./dist/bootstrap_nodes.txt | sed -E '/^$/d' | tr '\n' ',' | sed 's/,$//')"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENODE="'"$(cat ./el-bootnodes.txt | sed -E '/^$/d' | head -n1)"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENODE_LIST="'"$(cat ./el-bootnodes.txt | sed -E '/^$/d' | tr '\n' ',' | sed 's/,$//')"'"' >> ./dist/nodevars_env.txt

#!/bin/bash -e
set -x

source ./values.env


# get genesis details
tmp_dir=$(mktemp -d -t gd-XXXXXXXXXX)

cd apps/genesis-details
npm install @lodestar/types
node ./get-genesis-details.js ../../dist/genesis.ssz > $tmp_dir/details.txt
cd ../..

cat $tmp_dir/details.txt

echo 'ITERATION_NUMBER="'"$ITERATION_NUMBER"'"' >> ./dist/nodevars_env.txt
echo 'CHAIN_ID="'"$CHAIN_ID"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENR="'"$(cat ./dist/bootstrap_nodes.txt | sed -E '/^$/d' | head -n1)"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENR_LIST="'"$(cat ./dist/bootstrap_nodes.txt | sed -E '/^$/d' | tr '\n' ',' | sed 's/,$//')"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENODE="'"$(cat ./el-bootnodes.txt | sed -E '/^$/d' | head -n1)"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENODE_LIST="'"$(cat ./el-bootnodes.txt | sed -E '/^$/d' | tr '\n' ',' | sed 's/,$//')"'"' >> ./dist/nodevars_env.txt
echo 'GENESIS_TIME="'"$(cat $tmp_dir/details.txt | grep "genesisTime" | sed 's/.*: \(.*\)/\1/')"'"' >> ./dist/nodevars_env.txt
echo 'GENESIS_VALROOT="'"$(cat $tmp_dir/details.txt | grep "genesisValidatorsRoot" | sed 's/.*: \(.*\)/\1/')"'"' >> ./dist/nodevars_env.txt

cat $tmp_dir/details.txt | grep "genesisValidatorsRoot" | sed 's/.*: \(.*\)/\1/' > ./dist/genesis_validators_root.txt

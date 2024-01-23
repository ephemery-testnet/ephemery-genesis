#!/bin/bash -e
set -x

source ./values.env

echo 'ITERATION_NUMBER="'"$ITERATION_NUMBER"'"' >> ./dist/nodevars_env.txt
echo 'CHAIN_ID="'"$CHAIN_ID"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENR="'"$(cat ./dist/bootstrap_nodes.txt | sed -E '/^$/d' | head -n1)"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENR_LIST="'"$(cat ./dist/bootstrap_nodes.txt | sed -E '/^$/d' | tr '\n' ',' | sed 's/,$//')"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENODE="'"$(cat ./el-bootnodes.txt | sed -E '/^$/d' | head -n1)"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENODE_LIST="'"$(cat ./el-bootnodes.txt | sed -E '/^$/d' | tr '\n' ',' | sed 's/,$//')"'"' >> ./dist/nodevars_env.txt
echo 'GENESIS_TIME="'"$(cat ./dist/parsedBeaconState.json | jq -r .genesis_time)"'"' >> ./dist/nodevars_env.txt

genesis_validators_root=$(cat ./dist/parsedBeaconState.json | jq -r .genesis_validators_root)
echo 'GENESIS_VALROOT="'"$genesis_validators_root"'"' >> ./dist/nodevars_env.txt
echo $genesis_validators_root > ./dist/genesis_validators_root.txt

genesis_block_hash=$(cat ./dist/parsedBeaconState.json | jq -r .eth1_data.block_hash)
echo 'GENESIS_BLOCK="'"$genesis_block_hash"'"' >> ./dist/nodevars_env.txt
echo $genesis_block_hash > ./dist/deposit_contract_block_hash.txt

#!/bin/bash -e
set -x

source ./values.env


# get genesis details
tmp_dir=$(mktemp -d -t gd-XXXXXXXXXX)

cd apps/genesis-details
wget https://files.pythonhosted.org/packages/49/b0/eec486db30e95d7cc2bc2b5a878bdf829d7eb893e0c5c04c565418a236c5/eth2spec-1.1.10.tar.gz
tar xfz eth2spec-1.1.10.tar.gz
rm eth2spec-1.1.10.tar.gz
mv eth2spec-1.1.10/tests/core/pyspec/eth2spec ./eth2spec
rm -rf eth2spec-1.1.10
pip3 install -r requirements.txt
ln -s ../../dist/genesis.ssz ./genesis.ssz
python3 ./compute_genesis_details.py > $tmp_dir/details.txt
cd ../..


cat $tmp_dir/details.txt

echo 'ITERATION_NUMBER="'"$ITERATION_NUMBER"'"' >> ./dist/nodevars_env.txt
echo 'CHAIN_ID="'"$CHAIN_ID"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENR="'"$(cat ./dist/bootstrap_nodes.txt | sed -E '/^$/d' | head -n1)"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENR_LIST="'"$(cat ./dist/bootstrap_nodes.txt | sed -E '/^$/d' | tr '\n' ',' | sed 's/,$//')"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENODE="'"$(cat ./el-bootnodes.txt | sed -E '/^$/d' | head -n1)"'"' >> ./dist/nodevars_env.txt
echo 'BOOTNODE_ENODE_LIST="'"$(cat ./el-bootnodes.txt | sed -E '/^$/d' | tr '\n' ',' | sed 's/,$//')"'"' >> ./dist/nodevars_env.txt

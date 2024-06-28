#!/bin/bash -e
set -x

# rebuild old release structure
if [ -d ./dist2 ]; then
    rm -rf ./dist2
fi

mkdir ./dist2

# old structure         => new structure
#
# /bootnode-keys                => /bootnode-keys
# /besu.json                    => /metadata/besu.json
# /boot_enode.txt               => /metadata/enodes.txt
# /boot_enr.txt                 => /metadata/bootstrap_nodes.txt
# /boot_enr.yaml                => /metadata/bootstrap_nodes.txt [as yaml list]
# /bootnode.txt                 => /metadata/enodes.txt
# /bootstrap_nodes.txt          => /metadata/bootstrap_nodes.txt
# /chainspec.json               => /metadata/chainspec.json
# /config.yaml                  => /metadata/config.yaml
# /deploy_block.txt             => /metadata/deposit_contract_block.txt
# /deposit_contract.txt         => /metadata/deposit_contract.txt
# /deposit_contract_block.txt   => /metadata/deposit_contract_block.txt
# /deposit_contract_block_hash.txt => /metadata/deposit_contract_block_hash.txt
# /genesis.json                 => /metadata/genesis.json
# /genesis.ssz                  => /metadata/genesis.ssz
# /genesis_validators_root.txt  => /metadata/genesis_validators_root.txt
# /nodevars_env.txt             => /metadata/nodevars_env.txt
# /parsedBeaconState.json       => /parsed/parsedConsensusGenesis.json
# /retention.vars               => /retention.vars
# /validator-names.yaml         => /parsed/validator-names.yaml

cp ./dist/metadata/* ./dist2/
mv ./dist2/enodes.txt ./dist2/boot_enode.txt
cp ./dist2/boot_enode.txt ./dist2/bootnode.txt
cp ./dist2/bootstrap_nodes.txt ./dist2/boot_enr.txt
cat ./dist2/boot_enr.txt | awk '{print "- " $0}' > ./dist2/boot_enr.yaml
cp ./dist2/deposit_contract_block.txt ./dist2/deploy_block.txt

cp ./dist/parsed/parsedConsensusGenesis.json ./dist2/parsedBeaconState.json
cp ./dist/parsed/validator-names.yaml ./dist2/validator-names.yaml
cp ./dist/retention.vars ./dist2/retention.vars

cp ./dist/bootnode-keys -r ./dist2/bootnode-keys

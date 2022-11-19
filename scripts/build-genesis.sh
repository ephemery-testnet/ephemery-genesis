#!/bin/bash -e
source ./values.env
mkdir -p ./dist

setup_apps(){
    set -x
    cd ./apps

    if [ -d "./el-gen" ]; then
        cd el-gen
        pip3 install -r requirements.txt
        cd ..
    fi

    cd ..
}

gen_el_config(){
    set -x
    if ! [ -f "./dist/genesis.json" ]; then
        tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
        mkdir -p ./dist
        envsubst < ./el-config.yaml > $tmp_dir/genesis-config.yaml
        python3 ./apps/el-gen/genesis_geth.py $tmp_dir/genesis-config.yaml      > ./dist/genesis.json
        python3 ./apps/el-gen/genesis_chainspec.py $tmp_dir/genesis-config.yaml > ./dist/chainspec.json
        python3 ./apps/el-gen/genesis_besu.py $tmp_dir/genesis-config.yaml > ./dist/besu.json
        cp ./el-bootnodes.txt ./dist/boot_enode.txt
    else
        echo "el genesis already exists. skipping generation..."
    fi
}

gen_cl_config(){
    set -x
    # Consensus layer: Check if genesis already exists
    if ! [ -f "./dist/genesis.ssz" ]; then
        tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
        mkdir -p ./dist
        # Replace environment vars in files
        envsubst < ./cl-config.yaml > ./dist/config.yaml

        # Replace MIN_GENESIS_TIME on config
        sed "s/^MIN_GENESIS_TIME:.*/MIN_GENESIS_TIME: ${GENESIS_TIMESTAMP}/" ./dist/config.yaml > $tmp_dir/config.yaml
        mv $tmp_dir/config.yaml ./dist/config.yaml

        # Create deposit_contract.txt and deploy_block.txt
        grep DEPOSIT_CONTRACT_ADDRESS ./dist/config.yaml | cut -d " " -f2 > ./dist/deposit_contract.txt
        echo $DEPOSIT_CONTRACT_BLOCK > ./dist/deploy_block.txt
        echo $CL_EXEC_BLOCK > ./dist/deposit_contract_block.txt

        # collect validators
        cat ./validators/*.txt | sed 's/#.*$//g' > $tmp_dir/validators.txt

        # Generate genesis
        eth2-testnet-genesis merge \
        --config ./dist/config.yaml \
        --mnemonics $tmp_dir/validators.txt \
        --eth1-config ./dist/genesis.json \
        --tranches-dir ./dist/tranches \
        --state-output ./dist/genesis.ssz
        
    else
        echo "cl genesis already exists. skipping generation..."
    fi
}

gen_all_config(){
    setup_apps
    echo 'export GENESIS_TIMESTAMP="'"${GENESIS_TIMESTAMP}"'"' > ./dist/retention.vars
    echo 'export GENESIS_RESET_INTERVAL="'"${GENESIS_INTERVAL}"'"' >> ./dist/retention.vars
    echo 'export CHAIN_ID="'"${CHAIN_ID}"'"' >> ./dist/retention.vars
    gen_el_config
    gen_cl_config

    ls -lah ./dist
}

gen_all_config

#!/bin/bash -e
source ./values.env

gen_all_config(){
    if [ -d ./dist ]; then
        rm -rf ./dist
    fi

    # prepare input configs for ethereum-genesis-generator
    if [ -d ./temp ]; then
        rm -rf ./temp
    fi
    mkdir -p ./temp/output
    mkdir -p ./temp/input/cl
    cp ./cl-config.yaml ./temp/input/cl/config.yaml
    echo "" > ./temp/input/cl/mnemonics.yaml
    mkdir -p ./temp/input/el
    cp ./el-config.yaml ./temp/input/el/genesis-config.yaml
    cp ./values.env ./temp/input/values.env

    # Create a dummy validator with iteration number in pubkey (required to get a unique forkdigest for each genesis iteration)
    dummyaddr=$(echo $ITERATION_NUMBER | awk '{printf("%040x\n", $1)}')
    echo "0xb54b2811832ff970d1b3e048271e4fc9c0f4dcccac17683724f972203a6130d8ee7c26ec9bde0183fcede171deaddc4b:0x010000000000000000000000$dummyaddr:16000000000" > ./temp/input/validators.txt
    
    # collect validators
    cat ./validators/*.txt | sed 's/#.*$//g' >> ./temp/input/validators.txt

    # run ethereum-genesis-generator
    docker run --rm -u $UID -v $PWD/temp/output:/data \
        -v $PWD/temp/input:/config \
        ethpandaops/ethereum-genesis-generator:3.3.5 \
        all

    # copy config folder structure
    mkdir ./dist
    cp ./temp/output/metadata -r ./dist/metadata
    cp ./temp/output/parsed -r ./dist/parsed
    
    if [ -f ./dist/metadata/mnemonics.yaml ]; then
        rm ./dist/metadata/mnemonics.yaml
    fi
    if [ -d ./dist/metadata/tranches ]; then
        rmdir ./dist/metadata/tranches
    fi

    rm -rf ./temp

    # build retention vars
    touch ./dist/retention.vars
    echo 'export ITERATION_NUMBER="'"${ITERATION_NUMBER}"'"' >> ./dist/retention.vars
    echo 'export ITERATION_RELEASE="ephemery-'"${ITERATION_NUMBER}"'"' >> ./dist/retention.vars
    echo 'export GENESIS_TIMESTAMP="'"${GENESIS_TIMESTAMP}"'"' >> ./dist/retention.vars
    echo 'export GENESIS_RESET_INTERVAL="'"${GENESIS_INTERVAL}"'"' >> ./dist/retention.vars
    echo 'export CHAIN_ID="'"${CHAIN_ID}"'"' >> ./dist/retention.vars

    # copy el bootnodes
    cp ./el-bootnodes.txt ./dist/metadata/enodes.txt

    ls -lah ./dist
}

gen_all_config

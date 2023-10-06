#!/bin/bash -e
source ./values.env
mkdir -p ./dist

check_file() {
    echo "check file: $1"
    if ! [ -f $1 ]; then
        >&2 echo "genesis check failed: file $1 not found"
        exit 1
    fi
    fsize=$(stat -c%s "$1")
    if ! [ $fsize -gt 0 ]; then
        >&2 echo "genesis check failed: file $1 is empty"
        exit 1
    fi
}

check_genesis(){
    cd ./dist

    check_file besu.json
    check_file chainspec.json
    check_file genesis.json
    check_file config.yaml
    check_file genesis.ssz
    check_file boot_enode.txt
    check_file deploy_block.txt
    check_file deposit_contract_block.txt
    check_file deposit_contract.txt
    check_file retention.vars
    check_file nodevars_env.txt

    cd ..
}

check_genesis

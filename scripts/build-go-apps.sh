#!/bin/bash -e
set -x
cd ./apps

go install github.com/protolambda/eth2-val-tools@latest

if ! [ -d "./eth2-testnet-genesis" ]; then
    git clone https://github.com/pk910/eth2-testnet-genesis.git
    cd eth2-testnet-genesis
    go install .
    cd ..
fi
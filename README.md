# Test ephemeral testnet

This repository contains the genesis configuration for the test ephemeral testnet.

## Run clients

Use the [retention.sh](https://github.com/pk910/test-testnet-scripts/blob/master/retention.sh) script with a crontab (5mins) to reset your node to the latest genesis.
The script downloads the latest genesis state from this repository, initializes EL database and restarts the clients when necessary.
You'll need to modify the first 4 functions yourself to work in your environment.

## Add validators

To add validators to the genesis state you just need to commit the pubkeys to a new txt file within the validators folder of this repository.

They will be added to the genesis state on next reset.

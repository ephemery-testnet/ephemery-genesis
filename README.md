# Test ephemeral testnet

This repository contains the genesis configuration for the [test ephemeral testnet](https://github.com/ephemery-testnet/ephemery-resources).

## Run clients

Use the [retention.sh](https://github.com/ephemery-testnet/ephemery-scripts/blob/master/retention.sh) script with a crontab (5mins) to reset your node to the latest genesis.
The script downloads the latest genesis state from this repository, initializes EL database and restarts the clients when necessary.
You'll need to modify the first 4 functions yourself to work in your environment.

## Add validators

To add validators to the genesis state you just need to commit the pubkeys to a new txt file within the validators folder of this repository.

You can use [eth2-val-tools](https://github.com/protolambda/eth2-val-tools) in a command like this one to generate a 200 validators file:

```
export MNEMONIC="your mnemonic"
eth2-val-tools deposit-data --fork-version 0x10001008 --source-max 200 --source-min 0 --validators-mnemonic="$MNEMONIC" --withdrawals-mnemonic="$MNEMONIC" --as-json-list | jq ".[] | \"0x\" + .pubkey + \":\" + .withdrawal_credentials + \":32000000000\"" | tr -d '"' > name-node1.txt
```
Alternativally, you can also use [staking-deposit-cli](https://github.com/remyroy/staking-deposit-cli/releases/tag/v2.3.0.ephemery) which provides a guide. Complete the process using a new or existing mnemonic and parse the generated file with a command like this:

```
cat deposit_data-*.json | jq ".[] | \"0x\" + .pubkey + \":\" + .withdrawal_credentials + \":32000000000\"" | tr -d '"' > name-node1.txt

```

They will be added to the genesis state on next reset.

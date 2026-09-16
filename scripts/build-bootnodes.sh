#!/bin/bash -e
set -x

# NOTE: gloas-capable client builds are required to load the genesis state.
# There is no stable lighthouse/teku release with gloas support yet,
# so the ethpandaops unstable/master images (as used on glamsterdam devnets) are used here.
lighthouse_image="ethpandaops/lighthouse:unstable"
teku_image="ethpandaops/teku:master"

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
mkdir -p $tmp_dir
mkdir -p ./dist/bootnode-keys

if [ -f ./dist/metadata/bootstrap_nodes.txt ]; then
  rm ./dist/metadata/bootstrap_nodes.txt
fi
if [ -f ./dist/metadata/bootstrap_nodes.yaml ]; then
  rm ./dist/metadata/bootstrap_nodes.yaml
fi
if [ -f ./dist/metadata/enodes.txt ]; then
  rm ./dist/metadata/enodes.txt
fi

add_bootnode_enr() {
  echo "add enr: $1"
  echo "$1" >> ./dist/metadata/bootstrap_nodes.txt
  echo "- $1" >> ./dist/metadata/bootstrap_nodes.yaml
}

add_bootnode_key() {
  bootnode_name="$1"
  bootnode_keyfile="$2"
  bootnode_pubkey="${bootnode_name}.pub"
  if [ -f ./bootnode-keys/$bootnode_pubkey ]; then
    openssl rsautl -encrypt -inkey ./bootnode-keys/$bootnode_pubkey -pubin -in $bootnode_keyfile -out ./dist/bootnode-keys/${bootnode_name}.key.enc
  fi
}

add_bootnode_enode() {
  echo "add enode: $1"
  echo "$1" >> ./dist/metadata/enodes.txt
}

# wait up to $2 seconds for file $1 to appear
wait_for_file() {
  for i in $(seq 1 $2); do
    if [ -f "$1" ]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# build cl bootnodes
cat ./cl-bootnodes.txt | while read line ; do
  if [ -z "$line" ] || [[ "$line" == \#* ]]; then
    continue
  fi

  bootnode_data=($(echo $line | tr ":" " "))
  if [ ${bootnode_data[0]} = "enr" ]; then
    # generic ENR
    add_bootnode_enr $line
  elif [ ${bootnode_data[0]} = "lh_bootnode" ]; then
    rm -rf $tmp_dir/*
    docker run -d --name lh-bootnode -u $UID -v ./dist/metadata:/testnet:ro -v $tmp_dir:/data \
      $lighthouse_image lighthouse boot_node --testnet-dir /testnet --datadir /data \
      --port ${bootnode_data[3]} --enr-address ${bootnode_data[2]}
    wait_for_file $tmp_dir/beacon/network/enr.dat 60
    docker rm -f lh-bootnode
    sleep 2
    bootnode_enr=$(cat $tmp_dir/beacon/network/enr.dat)
    if [ ! -z "$bootnode_enr" ]; then
      echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[1]}.enr
      add_bootnode_key ${bootnode_data[1]} $tmp_dir/beacon/network/key
      add_bootnode_enr $bootnode_enr
    fi
  elif [ ${bootnode_data[0]} = "lighthouse" ]; then
    rm -rf $tmp_dir/*
    echo -n 0x$(openssl rand -hex 32 | tr -d "\n") > $tmp_dir/jwtsecret
    docker run -d --name lighthouse-node -u $UID -v ./dist/metadata:/testnet:ro -v $tmp_dir:/data \
      $lighthouse_image lighthouse bn --testnet-dir /testnet --datadir /data \
      --execution-endpoint http://172.17.0.1:8651 --execution-jwt /data/jwtsecret \
      --enr-address ${bootnode_data[2]} --enr-udp-port ${bootnode_data[3]} --port ${bootnode_data[3]} \
      --allow-insecure-genesis-sync
    wait_for_file $tmp_dir/beacon/network/enr.dat 90
    docker rm -f lighthouse-node
    sleep 2
    bootnode_enr=$(cat $tmp_dir/beacon/network/enr.dat)
    if [ ! -z "$bootnode_enr" ]; then
      echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[1]}.enr
      add_bootnode_key ${bootnode_data[1]} $tmp_dir/beacon/network/key
      add_bootnode_enr $bootnode_enr
    fi
  elif [ ${bootnode_data[0]} = "teku" ]; then
    rm -rf $tmp_dir/*
    echo -n 0x$(openssl rand -hex 32 | tr -d "\n") > $tmp_dir/jwtsecret
    docker run -d --restart unless-stopped --name teku-node -u $UID -v ./dist/metadata:/testnet:ro -p 5052:5052 -v $tmp_dir:/data $teku_image \
      --network=/testnet/config.yaml --initial-state=/testnet/genesis.ssz \
      --ee-endpoint=http://172.17.0.1:8651 --ee-jwt-secret-file=/data/jwtsecret \
      --data-path=/data --p2p-enabled=true --p2p-interface=0.0.0.0 --p2p-advertised-ip=${bootnode_data[2]} --p2p-port=${bootnode_data[3]} --p2p-advertised-port=${bootnode_data[3]} \
      --rest-api-enabled --rest-api-interface=0.0.0.0 --rest-api-host-allowlist=* --rest-api-port=5052 \
      --ignore-weak-subjectivity-period-enabled --data-storage-non-canonical-blocks-enabled=true
    bootnode_enr=""
    for i in $(seq 1 90); do
      bootnode_enr=$(curl -s http://127.0.0.1:5052/eth/v1/node/identity | jq -r .data.enr)
      if [ ! -z "$bootnode_enr" ] && [ "$bootnode_enr" != "null" ]; then
        break
      fi
      sleep 1
    done
    docker rm -f teku-node
    sleep 2
    if [ ! -z "$bootnode_enr" ] && [ "$bootnode_enr" != "null" ]; then
      echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[1]}.enr
      add_bootnode_key ${bootnode_data[1]} $tmp_dir/beacon/kvstore/generated-node-key.dat
      add_bootnode_enr $bootnode_enr
    fi
  fi
done

# build el bootnodes

cat ./el-bootnodes.txt | while read line ; do
  if [ -z "$line" ] || [[ "$line" == \#* ]]; then
    continue
  fi

  add_bootnode_enode $line
done

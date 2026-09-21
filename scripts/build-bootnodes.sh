#!/bin/bash -e
set -x

# Client images used to generate the bootnode ENRs.
# The images must be able to load the genesis state of the current iteration,
# so they need to support all forks that are active at genesis.
# Override via environment (eg. LIGHTHOUSE_IMAGE=sigp/lighthouse:v8.0.0) to switch images.
LIGHTHOUSE_IMAGE="${LIGHTHOUSE_IMAGE:-ethpandaops/lighthouse:unstable}"
TEKU_IMAGE="${TEKU_IMAGE:-ethpandaops/teku:master}"

# max seconds to wait for a client to write its ENR
BOOTNODE_TIMEOUT="${BOOTNODE_TIMEOUT:-120}"

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
chmod 777 $tmp_dir
metadata_dir="$(pwd)/dist/metadata"
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

# wait_for_file <file> <timeout seconds>
wait_for_file() {
  for i in $(seq 1 $2); do
    if [ -s "$1" ]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# stop_container <name>: print the container logs and remove it
stop_container() {
  echo "--- $1 logs ---"
  docker logs --tail 50 $1 2>&1 || true
  echo "--- end $1 logs ---"
  docker rm -f $1 > /dev/null 2>&1 || true
}

bootnode_failed() {
  >&2 echo "WARNING: could not generate ENR for bootnode $1 ($2)"
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
    # lighthouse boot_node (discovery only)
    rm -rf $tmp_dir/*
    docker run -d --name lh-bootnode -u $UID -v $metadata_dir:/testnet:ro -v $tmp_dir:/data $LIGHTHOUSE_IMAGE \
      lighthouse boot_node --testnet-dir /testnet --datadir /data \
      --port ${bootnode_data[3]} --enr-address ${bootnode_data[2]}
    wait_for_file $tmp_dir/beacon/network/enr.dat $BOOTNODE_TIMEOUT || true
    stop_container lh-bootnode
    bootnode_enr=$(cat $tmp_dir/beacon/network/enr.dat 2>/dev/null || true)
    if [ ! -z "$bootnode_enr" ]; then
      echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[1]}.enr
      add_bootnode_key ${bootnode_data[1]} $tmp_dir/beacon/network/key
      add_bootnode_enr $bootnode_enr
    else
      bootnode_failed ${bootnode_data[1]} "lighthouse boot_node, image $LIGHTHOUSE_IMAGE"
    fi
  elif [ ${bootnode_data[0]} = "lighthouse" ]; then
    # lighthouse beacon node
    rm -rf $tmp_dir/*
    echo -n 0x$(openssl rand -hex 32 | tr -d "\n") > $tmp_dir/jwtsecret
    docker run -d --name lh-beacon -u $UID -v $metadata_dir:/testnet:ro -v $tmp_dir:/data $LIGHTHOUSE_IMAGE \
      lighthouse bn --testnet-dir /testnet --datadir /data \
      --execution-endpoint http://172.17.0.1:8651 --execution-jwt /data/jwtsecret \
      --enr-address ${bootnode_data[2]} --enr-udp-port ${bootnode_data[3]} --port ${bootnode_data[3]} \
      --allow-insecure-genesis-sync
    wait_for_file $tmp_dir/beacon/network/enr.dat $BOOTNODE_TIMEOUT || true
    stop_container lh-beacon
    bootnode_enr=$(cat $tmp_dir/beacon/network/enr.dat 2>/dev/null || true)
    if [ ! -z "$bootnode_enr" ]; then
      echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[1]}.enr
      add_bootnode_key ${bootnode_data[1]} $tmp_dir/beacon/network/key
      add_bootnode_enr $bootnode_enr
    else
      bootnode_failed ${bootnode_data[1]} "lighthouse bn, image $LIGHTHOUSE_IMAGE"
    fi
  elif [ ${bootnode_data[0]} = "teku" ]; then
    # teku beacon node
    rm -rf $tmp_dir/*
    echo -n 0x$(openssl rand -hex 32 | tr -d "\n") > $tmp_dir/jwtsecret
    docker run -d --name teku-node -u $UID -v $metadata_dir:/testnet:ro -p 127.0.0.1:5052:5052 -v $tmp_dir:/data $TEKU_IMAGE \
      --network=/testnet/config.yaml --initial-state=/testnet/genesis.ssz \
      --ee-endpoint=http://172.17.0.1:8651 --ee-jwt-secret-file=/data/jwtsecret \
      --data-path=/data --p2p-enabled=true --p2p-interface=0.0.0.0 --p2p-advertised-ip=${bootnode_data[2]} --p2p-port=${bootnode_data[3]} --p2p-advertised-port=${bootnode_data[3]} \
      --rest-api-enabled --rest-api-interface=0.0.0.0 --rest-api-host-allowlist=* --rest-api-port=5052 \
      --ignore-weak-subjectivity-period-enabled --data-storage-non-canonical-blocks-enabled=true
    bootnode_enr=""
    for i in $(seq 1 $BOOTNODE_TIMEOUT); do
      bootnode_enr=$(curl -s http://127.0.0.1:5052/eth/v1/node/identity | jq -r '.data.enr // empty' 2>/dev/null || true)
      if [ ! -z "$bootnode_enr" ]; then
        # teku publishes a pre-genesis ENR first, re-fetch once the node has settled
        sleep 5
        settled_enr=$(curl -s http://127.0.0.1:5052/eth/v1/node/identity | jq -r '.data.enr // empty' 2>/dev/null || true)
        if [ ! -z "$settled_enr" ]; then
          bootnode_enr="$settled_enr"
        fi
        break
      fi
      sleep 1
    done
    stop_container teku-node
    if [ ! -z "$bootnode_enr" ]; then
      echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[1]}.enr
      add_bootnode_key ${bootnode_data[1]} $tmp_dir/beacon/kvstore/generated-node-key.dat
      add_bootnode_enr $bootnode_enr
    else
      bootnode_failed ${bootnode_data[1]} "teku, image $TEKU_IMAGE"
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

rm -rf $tmp_dir

# Fail if we generated fewer bootnodes than cl-bootnodes.txt defines.
# Silent shortfalls used to ship degraded configs (eg. only 2 of 5 ENRs).
expected_cl=$(grep -cE '^[^#[:space:]]' ./cl-bootnodes.txt)
expected_el=$(grep -cE '^[^#[:space:]]' ./el-bootnodes.txt)
actual_cl=$(grep -c . ./dist/metadata/bootstrap_nodes.txt)
actual_el=$(grep -c . ./dist/metadata/enodes.txt)

echo "generated $actual_cl/$expected_cl cl bootnodes, $actual_el/$expected_el el bootnodes"

if [ "$actual_cl" -lt "$expected_cl" ] || [ "$actual_el" -lt "$expected_el" ]; then
  >&2 echo "bootnode check failed: expected $expected_cl cl / $expected_el el bootnodes, got $actual_cl / $actual_el"
  exit 1
fi

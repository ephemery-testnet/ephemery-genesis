#!/bin/bash -e
set -x

get_github_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

if ! [ -d ./temp/lighthouse ]; then
  mkdir -p ./temp/lighthouse
  cd ./temp/lighthouse

  lighthouse_release=$(get_github_release sigp/lighthouse)
  wget "https://github.com/sigp/lighthouse/releases/download/$lighthouse_release/lighthouse-${lighthouse_release}-x86_64-unknown-linux-gnu-portable.tar.gz"
  tar xfz ./lighthouse-${lighthouse_release}-x86_64-unknown-linux-gnu-portable.tar.gz
  chmod +x ./lighthouse

  cd ../..
fi

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
mkdir -p $tmp_dir
mkdir -p ./dist/bootnode-keys

if [ -f ./dist/metadata/bootstrap_nodes.txt ]; then
  rm ./dist/metadata/bootstrap_nodes.txt
fi

add_bootnode_enr() {
  echo "add enr: $1"
  echo "$1" >> ./dist/metadata/bootstrap_nodes.txt
}

add_bootnode_key() {
  bootnode_name="$1"
  bootnode_keyfile="$2"
  bootnode_pubkey="${bootnode_name}.pub"
  if [ -f ./bootnode-keys/$bootnode_pubkey ]; then
    openssl rsautl -encrypt -inkey ./bootnode-keys/$bootnode_pubkey -pubin -in $bootnode_keyfile -out ./dist/bootnode-keys/${bootnode_name}.key.enc
  fi
}

cat ./cl-bootnodes.txt | while read line ; do
    bootnode_data=($(echo $line | tr ":" " "))
    if [ ${bootnode_data[0]} = "enr" ]; then
      # generic ENR
      add_bootnode_enr $line
    elif [ ${bootnode_data[0]} = "lh_bootnode" ]; then
      rm -rf $tmp_dir/*
      ./temp/lighthouse/lighthouse boot_node --testnet-dir ./dist/metadata --datadir $tmp_dir --port ${bootnode_data[3]} --enr-address ${bootnode_data[2]} &
      sleep 2
      killall lighthouse
      sleep 2
      bootnode_enr=$(cat $tmp_dir/beacon/network/enr.dat)
      if [ ! -z "$bootnode_enr" ]; then
        echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[1]}.enr
        add_bootnode_key ${bootnode_data[1]} $tmp_dir/beacon/network/key
        add_bootnode_enr $bootnode_enr
      fi
    elif [ ${bootnode_data[0]} = "lighthouse" ]; then
      rm -rf $tmp_dir/*
      ./temp/lighthouse/lighthouse bn --testnet-dir ./dist/metadata --datadir $tmp_dir --enr-address ${bootnode_data[2]} --enr-udp-port ${bootnode_data[3]} --port ${bootnode_data[3]} &
      sleep 10
      killall lighthouse
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
      docker run -d --restart unless-stopped --name teku-node -u $UID -v ./dist/metadata:/testnet:ro -p 5052:5052 -v $tmp_dir:/data consensys/teku:latest \
        --network=/testnet/config.yaml --initial-state=/testnet/genesis.ssz \
        --ee-endpoint=http://172.17.0.1:8651 --ee-jwt-secret-file=/data/jwtsecret \
        --data-path=/data --p2p-enabled=true --p2p-interface=0.0.0.0 --p2p-advertised-ip=${bootnode_data[2]} --p2p-port=${bootnode_data[3]} --p2p-advertised-port=${bootnode_data[3]} \
        --rest-api-enabled --rest-api-interface=0.0.0.0 --rest-api-host-allowlist=* --rest-api-port=5052 \
        --Xpeer-rate-limit=100000 --Xpeer-request-limit=1000 --ignore-weak-subjectivity-period-enabled --data-storage-non-canonical-blocks-enabled=true
      sleep 10
      bootnode_enr=$(curl -s http://127.0.0.1:5052/eth/v1/node/identity | jq -r .data.enr)
      docker rm -f teku-node
      sleep 2
      if [ ! -z "$bootnode_enr" ]; then
        echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[1]}.enr
        add_bootnode_key ${bootnode_data[1]} $tmp_dir/beacon/kvstore/generated-node-key.dat
        add_bootnode_enr $bootnode_enr
      fi
    fi
done


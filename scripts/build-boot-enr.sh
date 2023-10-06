#!/bin/bash -e
set -x

get_github_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

if ! [ -d ./apps/lighthouse ]; then
  mkdir ./apps/lighthouse
  cd ./apps/lighthouse

  lighthouse_release=$(get_github_release sigp/lighthouse)
  wget "https://github.com/sigp/lighthouse/releases/download/$lighthouse_release/lighthouse-${lighthouse_release}-x86_64-unknown-linux-gnu-portable.tar.gz"
  tar xfz ./lighthouse-${lighthouse_release}-x86_64-unknown-linux-gnu-portable.tar.gz
  chmod +x ./lighthouse

  cd ../..
fi

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
mkdir -p $tmp_dir
mkdir -p ./dist/bootnode-keys

add_bootnode_enr() {
  echo "$1" >> ./dist/bootstrap_nodes.txt
  echo "- $1" >> ./dist/boot_enr.txt
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
      ./apps/lighthouse/lighthouse boot_node --testnet-dir ./dist --datadir $tmp_dir --port ${bootnode_data[3]} ${bootnode_data[2]} &
      sleep 2
      killall lighthouse
      sleep 2
      bootnode_enr=$(cat $tmp_dir/beacon/network/enr.dat)
      echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[1]}.enr
      add_bootnode_key ${bootnode_data[1]} $tmp_dir/beacon/network/key
      add_bootnode_enr $bootnode_enr
    elif [ ${bootnode_data[0]} = "lighthouse" ]; then
      rm -rf $tmp_dir/*
      ./apps/lighthouse/lighthouse bn --testnet-dir ./dist --datadir $tmp_dir --enr-address ${bootnode_data[2]} --enr-udp-port ${bootnode_data[3]} --port ${bootnode_data[3]} &
      sleep 10
      killall lighthouse
      sleep 2
      bootnode_enr=$(cat $tmp_dir/beacon/network/enr.dat)
      echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[1]}.enr
      add_bootnode_key ${bootnode_data[1]} $tmp_dir/beacon/network/key
      add_bootnode_enr $bootnode_enr
    fi
done


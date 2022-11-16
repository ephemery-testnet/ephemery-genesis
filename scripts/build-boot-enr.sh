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

cat ./cl-bootnodes.txt | while read line ; do
    bootnode_data=($(echo $line | tr ":" " "))
    bootnode_pubkey="${bootnode_data[2]}.pub"
    if [ -f ./bootnode-keys/$bootnode_pubkey ]; then
        rm -rf $tmp_dir/*

        ./apps/lighthouse/lighthouse boot_node --testnet-dir ./dist --datadir $tmp_dir --port ${bootnode_data[1]} ${bootnode_data[0]} &
        sleep 2
        killall lighthouse
        sleep 2

        if ! [ -f $tmp_dir/beacon/network/enr.dat ]; then
          echo "couldn't generate enr bootnode for ${bootnode_data[0]}:${bootnode_data[1]}"
        else
          bootnode_enr=$(cat $tmp_dir/beacon/network/enr.dat)
          echo "$bootnode_enr" >> ./dist/bootstrap_nodes.txt
          echo "- $bootnode_enr" >> ./dist/boot_enr.txt

          echo "$bootnode_enr" >> ./dist/bootnode-keys/${bootnode_data[2]}.enr
          openssl rsautl -encrypt -inkey ./bootnode-keys/$bootnode_pubkey -pubin -in $tmp_dir/beacon/network/key -out ./dist/bootnode-keys/${bootnode_data[2]}.key.enc
        fi
    fi
done


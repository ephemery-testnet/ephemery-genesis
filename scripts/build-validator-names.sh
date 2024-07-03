#!/bin/bash -e
shopt -s lastpipe

source ./values.env

outfile=./dist/parsed/validator-names.yaml

val_name_idx=1
val_name_count=1
echo "0: "'"'"gvr_seed"'"' > $outfile

for f in ./validators/*.txt; do
  validator_name=`echo $f | sed 's/^\.\/validators\///' | sed 's/\.txt$//'`
  echo "Processing $f file... $validator_name";
  validator_count=0

  (cat $f | sed 's/#.*$//g' && echo "") | {
    while read -r line ; do
      pubkey=`echo $line | cut -d':' -f1 | sed 's/^0x//'`
      if [ ! -z "$pubkey" ]; then
        validator_count=$(expr $validator_count + 1)
      fi
    done

    validator_start_idx="$val_name_idx"
    val_name_idx=$(expr $val_name_idx + $validator_count)
    validator_end_idx=$(expr $val_name_idx - 1)

    if [ $validator_count -gt 0 ]; then
      val_name_count=$(expr $val_name_count + 1)

      if [ $validator_count -gt 1 ]; then
        echo "${validator_start_idx}-${validator_end_idx}: "'"'"$validator_name"'"' >> $outfile
      else
        echo "${validator_start_idx}: "'"'"$validator_name"'"' >> $outfile
      fi
    fi
  }
done
echo "Total Validator Names: $val_name_count ($val_name_idx indexes)"

#!/bin/bash

declare -a minion_ips

echo "Amount"
read minion_amount

for i in "${minion_ips[@]}"
  do
    echo "Minion $i:"
    read minion_ips[$i]
done

for y in "${minion_ips[@]}"
  do
    echo ${minion_ips[$y]}
done

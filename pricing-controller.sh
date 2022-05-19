#!/bin/bash

IFS=$'\n'
while true; do 
    for line in $(kubectl get nodes --no-headers --selector node.kubernetes.io/instance-type --selector karpenter.sh/capacity-type -L node.kubernetes.io/instance-type -L karpenter.sh/capacity-type -L topology.kubernetes.io/zone | tr -s " "); do
        node=$(echo ${line} | cut -d' ' -f1)
        instanceType=$(echo ${line} | cut -d' ' -f6)
        capacityType=$(echo ${line} | cut -d' ' -f7)
        zone=$(echo ${line} | cut -d' ' -f8)
        if [[ ${capacityType} = "spot" ]]; then 
            spotPrice=$(aws ec2 describe-spot-price-history --region "${zone%?}" --availability-zone "${zone}" --instance-types "${instanceType}" --max-items=1 --product-descriptions='Linux/UNIX' | jq -r '.SpotPriceHistory[] .SpotPrice')
            odPrice=$(odpricing "${instanceType}")
            set -x
            discount=$(echo "${spotPrice} ${odPrice}" | awk '{print ($1 / $2) * 100}')
            discount_int=$(printf %.0f $discount)
            kubectl label nodes ${node} "node.k8s.aws/spot-percent-discount=${discount_int}" --overwrite
        fi
    done
    sleep 10
done
#!/bin/bash
# This starts the RIC LXC container on POWDER
#  Call it as start-lxc-ric.sh
set -xeuo pipefail

RIC_LXC_IMG=ric
RIC_PORT=36422

echo "Initializing LXC container"
lxc init ${RIC_LXC_IMG} ${RIC_LXC_IMG}

echo "Configuring container security"
lxc config set ${RIC_LXC_IMG} security.privileged "yes"
lxc config set ${RIC_LXC_IMG} security.nesting "yes"

echo "Starting LXC container"
lxc start ${RIC_LXC_IMG}

echo "Setting postrouting chain"
HOST_IF=`route -e | grep default | awk -F ' ' '{print $8}'`
RIC_IF=`lxc list ${RIC_LXC_IMG} -c 6 --format=csv | awk -F '[()]' '{print $2}'`
RIC_IP=`lxc list ${RIC_LXC_IMG} -c 4 --format=csv | grep ${RIC_IF} | awk -F '[()]' '{print $1}'`
iptables -t nat -A PREROUTING -p sctp -i ${HOST_IF} --dport ${RIC_PORT} -j DNAT --to-destination ${RIC_IP}:${RIC_PORT}

echo "Starting RIC"
lxc exec ${RIC_LXC_IMG} -- bash -c "cd /root/radio_code/ric_bronze/ric-repository && ./setup-ric.sh "${RIC_IF}

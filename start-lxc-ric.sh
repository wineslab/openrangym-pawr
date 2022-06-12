#!/bin/bash
# This starts the RIC LXC container on POWDER
#  Call it as start-lxc-ric.sh
set -xeuo pipefail

RIC_LXC_IMG=ric
RIC_PORT=36422

SCRIPT_PATH="/root/radio_code/colosseum-near-rt-ric/setup-scripts"
#SCRIPT_PATH="/root/radio_code/ric_bronze/ric-repository"

echo "Flushing NAT table"
iptables -t nat -F

echo "Initializing LXC container"
lxc init local:${RIC_LXC_IMG} ${RIC_LXC_IMG}

echo "Configuring container security"
# lxc config set ${RIC_LXC_IMG} security.privileged "yes"
lxc config set ${RIC_LXC_IMG} security.nesting "yes"

echo "Starting LXC container"
lxc start ${RIC_LXC_IMG}

echo "Sleeping 10s"
sleep 10

echo "Setting postrouting chain"
HOST_IF=$(route -e | grep default | awk -F ' ' '{print $8}' | xargs)
RIC_IF=$(lxc list ${RIC_LXC_IMG} -c 6 --format=csv | awk -F '[()]' '{print $2}' | xargs)
RIC_IP=$(lxc list ${RIC_LXC_IMG} -c 4 --format=csv | grep ${RIC_IF} | awk -F '[()]' '{print $1}' | xargs)
iptables -t nat -A PREROUTING -p sctp -i ${HOST_IF} --dport ${RIC_PORT} -j DNAT --to-destination ${RIC_IP}:${RIC_PORT}

echo "Starting RIC"
# lxc exec ${RIC_LXC_IMG} -- bash -c "cd "${SCRIPT_PATH}" && ./import-base-images.sh"
lxc exec ${RIC_LXC_IMG} -- bash -c "docker image inspect e2term:latest >/dev/null 2>&1; if [[ ! $? -eq 0 ]]; then cd "${SCRIPT_PATH}"; ./import-base-images.sh; fi"

# sometimes internet connectivity in lxd container gets stuck.
# Restart lxd service to try to prevent this
echo "Restarting LXD"
if [[ ! $(service --status-all 2>&1 | grep lxd | wc -l) -eq 0 ]]; then
  service lxd restart
elif [[ ! $(snap list 2>&1 | grep lxd | wc -l) -eq 0 ]]; then
  snap restart lxd
else
  echo "Don't know how to restart LXD"
fi

lxc exec ${RIC_LXC_IMG} -- bash -c "cd "${SCRIPT_PATH}" && ./setup-ric.sh "${RIC_IF}
lxc exec ${RIC_LXC_IMG} -- bash -c "docker image prune -f"


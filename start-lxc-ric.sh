#!/bin/bash
# This starts the RIC LXC container on POWDER
#  Call it as start-lxc-ric.sh
set -xeuo pipefail

RIC_LXC_IMG=ric

echo "Initializing LXC container"
lxc init ${RIC_LXC_IMG} ${RIC_LXC_IMG}

echo "Configuring container security"
lxc config set ${RIC_LXC_IMG} security.privileged "yes"
lxc config set ${RIC_LXC_IMG} security.nesting "yes"

echo "Starting LXC container"
lxc start ${RIC_LXC_IMG}

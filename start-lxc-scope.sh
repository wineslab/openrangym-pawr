#!/bin/bash
# This starts the SCOPE LXC container on POWDER
#  Call it as start-lxc-scope.sh usrp_type, where usrp_type is either b210 or x310

set -xeuo pipefail

DU_LXC_BASE_IMG=du-scope
DU_LXC_IMG_UPGR=du-scope-1804
X310_NET=192.168.40.0

# check number of passed arguments
if [[ "$#" -ne 1 ]]; then
    echo "Illegal number of parameters. Call as start-lxc-scope.sh usrp_type"
    exit 1
fi


# build image if it does not exists
if [[ `lxc image show ${DU_LXC_IMG_UPGR} 2> /dev/null; echo $?` = "1" ]]; then
  echo "Updating image"
  . ./upgrade-scope-lxc.sh
fi

# set up containers to interface with USRPs
if [[ $1 == "b210" ]]; then
  echo "Configuring USB passthrough to LXC container"
  lxc config set ${DU_LXC_IMG_UPGR} raw.lxc "lxc.cgroup.devices.allow = c 189:* rwm"
  lxc config device add ${DU_LXC_IMG_UPGR} b210usb usb mode="0777"
elif [[ $1 == "x310" ]]; then
  echo "Adding Ethernet interface to X310"
  X310_IF=`route -n | grep ${X310_NET} | awk -F ' ' '{print $8}'`
  lxc config device add ${DU_LXC_IMG_UPGR} usrp1 nic name="usrp1" nictype="physical" parent="${X310_IF}"
else
  echo "Unknown passed parameter."
  exit 1
fi

echo "Configuring container security"
lxc config set ${DU_LXC_IMG_UPGR} security.privileged "yes"

echo "Starting container"
lxc start ${DU_LXC_IMG_UPGR}

if [[ $1 == "x310" ]]; then
  echo "Configuring Ethernet interface to X310"
  lxc exec ${DU_LXC_IMG_UPGR} -- bash -c "ifconfig usrp1 192.168.40.1/24 mtu 9000"

  echo "Downloading UHD images"
  lxc exec ${DU_LXC_IMG_UPGR} -- bash -c "/usr/local/lib/uhd/utils/uhd_images_downloader.py"

  echo "Flashing USRP device"
  lxc exec ${DU_LXC_IMG_UPGR} -- bash -c "/usr/local/bin/uhd_image_loader --args=\"type=x300,addr=192.168.40.2,fpga=XG\""

  echo "Setting memory on host computer"
  sudo sysctl -w net.core.wmem_max=24862979
fi

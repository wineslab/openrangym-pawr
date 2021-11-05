#!/bin/bash
# This starts the SCOPE LXC container on POWDER or ORBiT testbeds
#  Call it as start-lxc-scope.sh testbed usrp_type [flash]
#    testbed: powder or orbit
#    usrp_type: b210 or x310
#    flash: flash USRP X310 if passed
set -xeuo pipefail

# base image used in sourced script
DU_LXC_BASE_IMG=du-scope

# testbed images
DU_LXC_IMG_POWDER=du-scope-1804
DU_LXC_IMAGE_ORBIT=${DU_LXC_BASE_IMG}

X310_NET=192.168.40.0

# check number of passed arguments
if [[ $# -lt 2 ]]; then
    echo "Illegal number of parameters. Call as start-lxc-scope.sh usrp_type [flash]"
    exit 1
else
  TESTBED=$1
  USRP=$2
  FLASH=$3
fi

# check testbed
if [[ ${TESTBED} == "powder" ]]; then
  DU_LXC_IMG=${DU_LXC_IMG_POWDER}
elif [[ ${TESTBED}=="orbit" ]]; then
  DU_LXC_IMG=${DU_LXC_IMG_ORBIT}
else
  echo "Unknown passed testbed."
  exit 1
fi

# build image if it does not exists on powder testbed
if [[ ${TESTBED} == "powder" ]]; then
  if [[ `lxc image show ${DU_LXC_IMG} 2> /dev/null; echo $?` = "1" ]]; then
    echo "Updating image"
    . ./upgrade-scope-lxc.sh
  fi
fi

echo "Initializing LXC container"
lxc init ${DU_LXC_IMG} ${DU_LXC_IMG}

# set up containers to interface with USRP
if [[ ${USRP} == "b210" ]]; then
  echo "Configuring USB passthrough to LXC container"
  lxc config set ${DU_LXC_IMG} raw.lxc "lxc.cgroup.devices.allow = c 189:* rwm"
  lxc config device add ${DU_LXC_IMG} b210usb usb mode="0777"
elif [[ ${USRP} == "x310" ]]; then
  echo "Adding Ethernet interface to X310"
  X310_IF=`route -n | grep ${X310_NET} | awk -F ' ' '{print $8}'`
  lxc config device add ${DU_LXC_IMG} usrp1 nic name="usrp1" nictype="physical" parent="${X310_IF}"
else
  echo "Unknown passed parameter."
  exit 1
fi

echo "Configuring container security"
lxc config set ${DU_LXC_IMG} security.privileged "yes"

echo "Starting LXC container"
lxc start ${DU_LXC_IMG}

if [[ ${USRP} == "x310" ]]; then
  echo "Configuring Ethernet interface to X310"
  lxc exec ${DU_LXC_IMG} -- bash -c "ifconfig usrp1 192.168.40.1/24 mtu 9000"

  echo "Downloading UHD images"
  lxc exec ${DU_LXC_IMG} -- bash -c "/usr/local/lib/uhd/utils/uhd_images_downloader.py"

  if [[ ${FLASH} == "flash" ]]; then
    echo "Flashing USRP device"
    lxc exec ${DU_LXC_IMG} -- bash -c "/usr/local/bin/uhd_image_loader --args=\"type=x300,addr=192.168.40.2,fpga=XG\""
  fi

  echo "Setting memory on host computer"
  sysctl -w net.core.wmem_max=24862979
fi

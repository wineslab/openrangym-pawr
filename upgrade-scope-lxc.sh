#!/bin/bash
# This script takes the Colosseum DU-SCOPE Ubuntu 16.04 LXC image and ports it to an Ubuntu 18.04 LXC container
set -xeuo pipefail

DU_LXC_IMG=du-scope
DU_NEW_IMAGE=du-scope-1804

echo "Moving LXC pool to temporary volume and creating containers"
mkdir -p /mydata/var/lib/lxd/storage-pools/default/containers
lxc init local:${DU_LXC_IMG} ${DU_LXC_IMG}
lxc start ${DU_LXC_IMG}

lxc launch ubuntu:18.04 ${DU_NEW_IMAGE}
lxc stop ${DU_NEW_IMAGE}

echo "Setting USB passthrough to LXC container"
lxc config device add ${DU_NEW_IMAGE} b210usb usb mode="0777"
lxc config set ${DU_NEW_IMAGE} "raw.lxc lxc.cgroup.devices.allow = c 189:* rwm"
lxc start ${DU_NEW_IMAGE}

echo "Moving content to new container"
mkdir tmp && cd tmp
lxc file pull --recursive ${DU_LXC_IMG}/root .
lxc file push --recursive root ${DU_NEW_IMAGE}/
cd .. && rm -Rf tmp

echo "Installing dependencies"
lxc exec ${DU_NEW_IMAGE} -- bash -c "apt-get update && apt install -y \
  libboost-all-dev \
  libusb-1.0-0-dev \
  doxygen \
  python3-docutils \
  python3-mako \
  python3-numpy \
  python3-requests \
  python3-ruamel.yaml \
  python3-setuptools \
  cmake \
  build-essential \
  libboost-system-dev \
  libboost-test-dev \
  libboost-thread-dev \
  libqwt-qt5-dev \
  qtbase5-dev \
  libfftw3-dev \
  libmbedtls-dev \
  libboost-program-options-dev \
  libconfig++-dev \
  libsctp-dev \
  libzmq3-dev \
  libpcsclite-dev \
  openssh-server \
  && apt-get clean && rm -rf /var/cache/apt/archives"

echo "Cloning and building UHD 3.15"
lxc exec ${DU_NEW_IMAGE} -- bash -c "cd /root \
  && git clone https://github.com/EttusResearch/uhd.git \
  && mkdir -p uhd/host/build \
  && cd uhd/host/build \
  && git checkout v3.15.0.0 \
  && cmake .. \
  && make -j `nproc` \
  && make install \
  && ldconfig \
  && /usr/local/lib/uhd/utils/uhd_images_downloader.py"

echo "Cloning srsGUI"
lxc exec ${DU_NEW_IMAGE} -- bash -c "cd /root/radio_code \
  && rm -Rf srsGUI \
  && git clone https://github.com/srsran/srsGUI.git \
  && mkdir -p srsGUI/build \
  && cd srsGUI/build \
  && cmake .. \
  && make -j `nproc` \
  && make install \
  && ldconfig"

echo "Building SCOPE"
lxc exec ${DU_NEW_IMAGE} -- bash -c "cd /root/radio_code/srsLTE \
  && mkdir -p build \
  && cd build \
  && make clean \
  && cmake .. \
  && make -j `nproc` \
  && make install \
  && ldconfig"

# TODO: set SCOPE parameters

# TODO: compile DU

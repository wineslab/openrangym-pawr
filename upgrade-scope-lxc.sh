#!/bin/bash
# This script takes the Colosseum DU-SCOPE Ubuntu 16.04 LXC image and ports it to an Ubuntu 18.04 LXC container
set -xeuo pipefail

DU_LXC_BASE_IMG=du-scope
DU_LXC_IMG=du-scope-1804

# build image if it does not exists
if [[ `lxc image show ${DU_LXC_IMG} 2> /dev/null; echo $?` = "1" ]]; then
  echo "Updating image"
  echo "Moving LXC pool to temporary volume and creating base container"
  mkdir -p /mydata/var/lib/lxd/storage-pools/default/containers
  lxc init local:${DU_LXC_BASE_IMG} ${DU_LXC_BASE_IMG}
  lxc start ${DU_LXC_BASE_IMG}

  echo "Launching new container"
  lxc init ubuntu:18.04 ${DU_LXC_IMG}

  echo "Configuring USB passthrough to LXC container"
  lxc config set ${DU_LXC_IMG} raw.lxc "lxc.cgroup.devices.allow = c 189:* rwm"
  lxc config device add ${DU_LXC_IMG} b210usb usb mode="0777"

  echo "Configuring container security"
  lxc config set ${DU_LXC_IMG} security.privileged "yes"

  echo "Starting container"
  lxc start ${DU_LXC_IMG}

  echo "Moving content to new container"
  mkdir tmp && cd tmp
  lxc file pull --recursive ${DU_LXC_BASE_IMG}/root .
  lxc file push --recursive root ${DU_LXC_IMG}/
  cd .. && rm -Rf tmp

  echo "Removing base container"
  lxc stop ${DU_LXC_BASE_IMG}
  lxc rm ${DU_LXC_BASE_IMG}

  echo "Installing dependencies"
  lxc exec ${DU_LXC_IMG} -- bash -c "apt-get update && apt install -y \
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
    libpcap0.8-dev \
    && apt-get clean && rm -rf /var/cache/apt/archives"

  echo "Cloning and building UHD 3.15"
  lxc exec ${DU_LXC_IMG} -- bash -c "cd /root \
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
  lxc exec ${DU_LXC_IMG} -- bash -c "cd /root/radio_code \
    && rm -Rf srsGUI \
    && git clone https://github.com/srsran/srsGUI.git \
    && mkdir -p srsGUI/build \
    && cd srsGUI/build \
    && cmake .. \
    && make -j `nproc` \
    && make install \
    && ldconfig"

  echo "Building SCOPE"
  lxc exec ${DU_LXC_IMG} -- bash -c "cd /root/radio_code/srsLTE \
    && mkdir -p build \
    && cd build \
    && make clean \
    && cmake .. \
    && make -j `nproc` \
    && make install \
    && ldconfig"

  echo "Setting SCOPE parameters"
  lxc exec ${DU_LXC_IMG} -- bash -c "sed -i 's/^#*dl_freq\s*=\s*[[:alnum:]]*\s*$/dl_freq = 2435000000/g' /root/radio_code/srslte_config/enb.conf \
    && sed -i 's/^#*ul_freq\s*=\s*[[:alnum:]]*\s*$/ul_freq = 2415000000/g' /root/radio_code/srslte_config/enb.conf \
    && sed -i 's/^time_adv_nsamples\s*=\s*[[:alnum:]]*\s*$/time_adv_nsamples = auto/g' /root/radio_code/srslte_config/enb.conf \
    && sed -i 's/^#*colosseum_testbed\s*::\s*[[:alnum:]]*\s*$/colosseum_testbed::0/g' /root/radio_code/scope_config/scope_cfg.txt"

  # TODO: compile DU
  echo "Building DU"
  LXC_INTERNET_IF=`lxc list ${DU_LXC_IMG} -c 4 --format=csv | awk -F '[()]' '{print $2}'`
  lxc exec ${DU_LXC_IMG} -- bash -c "cd /root/radio_code/du-l2 \
    && sed -i 's/^export INTERFACE_TO_RIC\s*=.*$/export INTERFACE_TO_RIC=\"'${LXC_INTERNET_IF}'\"/g' /root/radio_code/du-l2/build_odu.sh \
    && sed -i 's/^export DEBUG\s*=.*$/export DEBUG=0/g' /root/radio_code/du-l2/build_odu.sh \
    && ./build_odu.sh clean"

  echo "Saving image"
  lxc publish du-scope-1804 --alias ${DU_LXC_IMG} --force
else
  echo "Starting image"
  lxc init ${DU_LXC_IMG} ${DU_LXC_IMG}

  echo "Configuring USB passthrough to LXC container"
  lxc config set ${DU_LXC_IMG} raw.lxc "lxc.cgroup.devices.allow = c 189:* rwm"
  lxc config device add ${DU_LXC_IMG} b210usb usb mode="0777"

  echo "Configuring container security"
  lxc config set ${DU_LXC_IMG} security.privileged "yes"

  echo "Starting container"
  lxc start ${DU_LXC_IMG}
fi

# OpenRAN Gym PAWR

Scripts to start OpenRAN Gym LXC containers on PAWR platforms (tested on POWDER, COSMOS, and Arena).
First, LXC images need to be transferred from Colosseum to the platform of interest (e.g., through `scp` or `rsync`).
Then:
- Start RIC with: `./start-lxc-ric.sh`
- Start SCOPE with: `./start-lxc-scope.sh testbed usrp_type [flash]`
- Optionally upgrade the SCOPE image to Ubuntu 18.04 (e.g., if there are compatibility issues with the USRPs) with: `upgrade-scope-lxc.sh`

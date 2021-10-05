#!/usr/bin/python

"""
Colosseum-based RIC LXC.
"""

import os

import geni.portal as portal
import geni.rspec.pg as rspec
import geni.rspec.emulab.pnext as pn
import geni.rspec.igext as ig
import geni.rspec.emulab.spectrum as spectrum
# Import Emulab-specific extensions so we can set node attributes.
import geni.rspec.emulab as emulab


MNGR_ID = "urn:publicid:IDN+emulab.net+authority+cm"

RIC_IMG = "urn:publicid:IDN+emulab.net+image+wicos:ric-colosseum"
DU_IMG = "urn:publicid:IDN+emulab.net+image+wicos:du-scope"
DU_LXC_IMAGE_NAME = "du-scope"

class GLOBALS(object):
    DLHIFREQ = 2440.0  # 2690.0
    DLLOFREQ = 2430.0  # 2680.0
    ULHIFREQ = 2410.0  # 2570.0
    ULLOFREQ = 2400.0  # 2560.0

def x310_node_pair(idx, x310_radio):
    node = request.RawPC("{}-comp".format(x310_radio.component_id))
    node.hardware_type = params.x310_pair_nodetype
    node.disk_image = DU_IMG
    node.component_manager_id = MNGR_ID
    node.addService(rspec.Execute(shell="bash", command="/local/repository/bin/tune-cpu.sh"))
    
    # allocate temporary disk space to initialize LXC container on
    bs = node.Blockstore("bs_x310_" + str(idx), "/mydata")
    bs.size = "30GB"
    
    # create LXC storage pool directory
    node.addService(rspec.Execute(shell="bash", command="sudo mkdir -p /mydata/var/lib/lxd/storage-pools/default"))

    node_radio_if = node.addInterface("usrp_if")
    node_radio_if.addAddress(rspec.IPv4Address("192.168.40.1",
                                               "255.255.255.0"))

    radio_link = request.Link("radio-link-{}".format(idx))
    radio_link.bandwidth = 10*1000*1000
    radio_link.addInterface(node_radio_if)

    radio = request.RawPC(x310_radio.component_id)
    radio.component_id = x310_radio.component_id
    radio.component_manager_id = MNGR_ID
    radio_link.addNode(radio)

    if params.connect_shvlan and idx == 0:
        shiface = node.addInterface("ifSharedVlan")
        if shvlan_address:
            shiface.addAddress(rspec.IPv4Address(shvlan_address, shvlan_netmask))

        sharedvlan = request.Link('shared_vlan')
        sharedvlan.addInterface(shiface)
        sharedvlan.connectSharedVlan(params.connect_shvlan)
        if params.multiplex_lans:
            sharedvlan.link_multiplexing = True
            sharedvlan.best_effort = True


def b210_nuc_pair(idx, b210_node):
    node = request.RawPC(b210_node.component_id)
    node.component_manager_id = MNGR_ID
    node.component_id = b210_node.component_id
    node.disk_image = DU_IMG
    node.addService(rspec.Execute(shell="bash", command="/local/repository/bin/tune-cpu.sh"))
    
    # allocate temporary disk space to initialize LXC container on
    bs = node.Blockstore("bs_b210_" + str(idx), "/mydata")
    bs.size = "30GB"
    
    # create LXC storage pool directory
    node.addService(rspec.Execute(shell="bash", command="sudo mkdir -p /mydata/var/lib/lxd/storage-pools/default"))


def allocate_compute_node(idx, compute_node):
    node = request.RawPC("{}-compute-only".format(idx))
    node.hardware_type = compute_node.component_id
    node.disk_image = RIC_IMG
    node.addService(rspec.Execute(shell="bash", command="/local/repository/bin/tune-cpu.sh"))
    
    # allocate temporary disk space to initialize LXC container on
    bs = node.Blockstore("bs_ric_" +str(idx), "/mydata")
    bs.size = "100GB"
    
    # create LXC storage pool directory
    node.addService(rspec.Execute(shell="bash", command="sudo mkdir -p /mydata/var/lib/lxd/storage-pools/default"))


pc = portal.Context()

node_type = [
    ("d740",
     "Emulab, d740"),
    ("d430",
     "Emulab, d430")
]

pc.defineParameter("dlspechi", "Downlink range high frequency",
                   portal.ParameterType.BANDWIDTH, GLOBALS.DLHIFREQ)

pc.defineParameter("dlspeclo", "Downlink range low frequency",
                   portal.ParameterType.BANDWIDTH, GLOBALS.DLLOFREQ)

pc.defineParameter("ulspechi", "Uplink range high frequency",
                   portal.ParameterType.BANDWIDTH, GLOBALS.ULHIFREQ)

pc.defineParameter("ulspeclo", "Uplink range low frequency",
                   portal.ParameterType.BANDWIDTH, GLOBALS.ULLOFREQ)

pc.defineParameter("x310_pair_nodetype",
                   "Type of compute node paired with the X310 Radios",
                   portal.ParameterType.STRING,
                   node_type[0],
                   node_type)

indoor_ota_x310s = [
    ("ota-x310-1",
     "USRP X310 #1"),
    ("ota-x310-2",
     "USRP X310 #2"),
    ("ota-x310-3",
     "USRP X310 #3"),
    ("ota-x310-4",
     "USRP X310 #4"),
]

pc.defineStructParameter("x310_radios", "X310 Radios", [],
                         multiValue=True,
                         itemDefaultValue={},
                         min=0, max=None,
                         members=[
                             portal.Parameter(
                                 "component_id",
                                 "Indoor OTA X310",
                                 portal.ParameterType.STRING,
                                 indoor_ota_x310s[0],
                                 indoor_ota_x310s)
                         ])

indoor_ota_nucs = [
    ("ota-nuc1",
     "nuc1 w/B210"),
    ("ota-nuc2",
     "nuc2 w/B210"),
    ("ota-nuc3",
     "nuc3 w/B210"),
    ("ota-nuc4",
     "nuc4 w/B210"),
]

pc.defineStructParameter("b210_nodes", "B210 Radios", [],
                         multiValue=True,
                         min=0, max=None,
                         members=[
                             portal.Parameter(
                                 "component_id",
                                 "NUC compute w/ B210",
                                 portal.ParameterType.STRING,
                                 indoor_ota_nucs[0],
                                 indoor_ota_nucs)
                         ],
                         )

pc.defineStructParameter("compute_nodes", "Compute Nodes", [],
                         multiValue=True,
                         min=0, max=None,
                         members=[
                             portal.Parameter(
                                 "component_id",
                                 "Compute Node",
                                 portal.ParameterType.STRING,
                                 node_type[0],
                                 node_type)
                         ],
                         )

pc.defineParameter(
    "multiplex_lans", "Multiplex Networks",
    portal.ParameterType.BOOLEAN,True,
    longDescription="Multiplex any networks over physical interfaces using VLANs.  Some physical machines have only a single experiment network interface, so if you want multiple links/LANs, you have to enable multiplexing.  Currently, if you select this option.",
    advanced=True)

pc.defineParameter(
    "connect_shvlan","Shared VLAN Name",
    portal.ParameterType.STRING,"",
    longDescription="Connect one of the X310 compute nodes to a shared VLAN. This allows your srsLTE experiment to connect to another experiment (e.g., one running ORAN services). The shared VLAN must already exist.",
    advanced=True)

pc.defineParameter(
    "shvlan_address","Shared VLAN IP Address",
    portal.ParameterType.STRING,"10.254.254.100/255.255.255.0",
    longDescription="Set the IP address and subnet mask for the shared VLAN interface.  Make sure you choose an unused address within the subnet of an existing shared vlan!  Also ensure that you specify the subnet mask as a dotted quad.",
    advanced=True)

pc.defineParameter(
    "oran_address","ORAN Services Gateway Address",
    portal.ParameterType.STRING,"10.254.254.1",
    longDescription="The IP address of the ORAN services gateway running on an adjacent experiment connected to the same shared VLAN.",
    advanced=True)

params = pc.bindParameters()

# Handle shared vlan address param.
shvlan_address, shvlan_netmask = None, None
if params.shvlan_address:
    aa = params.shvlan_address.split('/')
    if len(aa) != 2:
        perr = portal.ParameterError(
            "Invalid shared VLAN address!",
            ['shvlan_address'])
        pc.reportError(perr)
    else:
        shvlan_address, shvlan_netmask = aa[0], aa[1]

pc.verifyParameters()
request = pc.makeRequestRSpec()

request.requestSpectrum(params.dlspeclo, params.dlspechi, 100)
request.requestSpectrum(params.ulspeclo, params.ulspechi, 100)

for i, x310_radio in enumerate(params.x310_radios):
    x310_node_pair(i, x310_radio)

for i, b210_node in enumerate(params.b210_nodes):
    b210_nuc_pair(i, b210_node)

for i, compute_node in enumerate(params.compute_nodes):
    allocate_compute_node(i, compute_node)

pc.printRequestRSpec()

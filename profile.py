"""This profile instantiates a d840 machine connected to a Skylark FAROS massive MIMO system (64-antenna), comprised of FAROS hub and its connected Iris radio chains (four chains with four and two chains with eight Irises) as well as two Iris clients. The PC boots with Ubuntu 16.04 and includes a MATLAB installation that could be used to run experiments on FAROS with RENEWLab demos. For more information on RENEWLab, see [RENEW documentation page](https://docs.renew-wireless.org)

Instructions:
The FAROS hub and PC are connected via a private 10Gbps link. All Iris radios and the FAROS hub should come up with address between 192.168.1.101 and 192.168.1.200. These addresses are reachable by first logging in to the PC. For more information on how to start an experiment with massive MIMO equipment on POWDER, see [this page](https://docs.renew-wireless.org/getting-started/powder/). 

To get started with FAROS massive MIMO hardware, see [RENEW Hardware Documentation](https://docs.renew-wireless.org/getting-started/hardware/).

For questions about access to the required PC type and massive MIMO radio devices, please contact support@powderwireless.net

A step-by-step procedure to run simple demos is as follows:

- Once your experiment is ready, from your terminal, ssh to pc1 with X11 forwarding:
 
	`ssh -X USERNAME@pc19-meb.emulab.net`

- Go to the renew-software repository python demos folder: 

	`cd /local/repository/renew-software/PYTHON/DEMOS`

- Run example 1 (bursty oscilloscope and spectrum analyzer demo): 

	`sudo python3 SISO_RX.py --serial RF3E000143`

- Run example 2 (sending and receiving a sinewave burst between two Iris devices in tdd mode): 

	`python3 SISO_TXRX_TDD.py`

- In case you get the following error after running any of the examples, try re-running the code. This is a transient error, related to the discovery of Iris devices.

	`RuntimeError: SoapySDR::Device::make() no driver specified and no enumeration results`


To learn more about the rest of demos and examples and how to run your own apps, see [RENEWLab documentation](https://docs.renew-wireless.org/dev-suite/design-flows/)
"""

import geni.portal as portal
import geni.urn as urn
import geni.rspec.pg as pg
import geni.rspec.emulab as elab

# Resource strings
PCIMG = "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU16-64-STD"
PCHWTYPE = "d840"
FAROSHWTYPE = "faros_sfp"
IRISHWTYPE = "iris030"

#
# Profile parameters.
#

#pc = portal.Context()
#params = pc.bindParameters()
#pc.verifyParameters()

# Create a Request object to start building the RSpec.
request = portal.context.makeRequestRSpec()
 
# Request a PC
pc1 = request.RawPC("pc1")
#pc1.hardware_type = PCHWTYPE
pc1.component_id="pc19-meb"
pc1.disk_image = PCIMG
bs = request.RemoteBlockstore( "matlab1", "/usr/local/MATLAB" )
bs.dataset = "urn:publicid:IDN+emulab.net:powderprofiles+ltdataset+matlab-extra"
bs.rwclone = True
bslink = request.Link( "dslink1" )
bslink.addInterface( pc1.addInterface( "dsiface1" ) )
bslink.addInterface( bs.interface )
bslink.vlan_tagging = True
bslink.best_effort = True
pc1.addService(pg.Execute(shell="sh", command="/usr/bin/sudo /local/repository/faros_start.sh"))
if1pc1 = pc1.addInterface("if1pc1", pg.IPv4Address("192.168.1.1", "255.255.255.0"))
if1pc1.bandwidth = 40 * 1000 * 1000


# Request a Faros BS.
mm1 = request.RawPC("mm1")
mm1.hardware_type = FAROSHWTYPE
mm1if1 = mm1.addInterface("if1")
mm1if2 = mm1.addInterface("if2")
mm1if3 = mm1.addInterface("if3")
#mm1if4 = mm1.addInterface("if4")

# Request an Iris client.
ir1 = request.RawPC("ir1")
ir1.hardware_type = IRISHWTYPE
ir1.component_id = "iris03"  # in Mike's office
ir1if1 = ir1.addInterface("if1")

# Request another Iris client.
ir2 = request.RawPC("ir2")
ir2.hardware_type = IRISHWTYPE
ir2.component_id = "iris04"  # in Jon's office
ir2if1 = ir2.addInterface("if1")

# Connect the PC, BS, and Iris clients to a LAN
lan1 = request.LAN("lan1")
lan1.vlan_tagging = False
lan1.setNoBandwidthShaping()
lan1.addInterface(if1pc1)
lan1.addInterface(mm1if1)
lan1.addInterface(mm1if2)
lan1.addInterface(mm1if3)
#lan1.addInterface(mm1if4)
lan1.addInterface(ir1if1)
lan1.addInterface(ir2if1)

# Print the RSpec to the enclosing page.
portal.context.printRequestRSpec()

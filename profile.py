"""A profile that instantiates a PC connected to two Iris radios.  The radios are connected via RF cabling and switch matrix in the PhantomNet testbed.

Instructions:
The radios are each connected via a private 1Gbps link.  "iris1" should come up with address 192.168.1.101 and "iris2" should have 192.168.2.101.  These addresses are reachable by first logging in to "pc1".
"""

import geni.portal as portal
import geni.urn as urn
import geni.rspec.pg as pg
import geni.rspec.emulab as elab

# Resource strings
PCIMG = "urn:publicid:IDN+emulab.net+image+argos-test:soapyuhd"
PCHWTYPE = "d430"
IRISHWTYPE = "iris030"
#IRISIMG = "urn:publicid:IDN+phantomnet.org+image+emulab-ops:GENERICDEV-NOVLANS"

# Create a Request object to start building the RSpec.
request = portal.context.makeRequestRSpec()
 
# Request a PC
pc1 = request.RawPC("pc1")
pc1.hardware_type = PCHWTYPE
pc1.disk_image = PCIMG
pc1.addService(pg.Execute(shell="sh", command="/usr/bin/sudo /local/repository/irishost_start.sh"))
ifpc1ir1 = pc1.addInterface("pc1ir1", pg.IPv4Address("192.168.1.1", "255.255.255.0"))
ifpc1ir2 = pc1.addInterface("pc1ir2", pg.IPv4Address("192.168.2.1", "255.255.255.0"))

# Request an Iris SDR
ir1 = request.RawPC("iris1")
ir1.hardware_type = IRISHWTYPE
#ir1.disk_image = IRISIMG

# Request a second Iris SDR
ir2 = request.RawPC("iris2")
ir2.hardware_type = IRISHWTYPE
#ir2.disk_image = IRISIMG

# Connect nuc1 to ir1 over the wired net
link1 = request.Link("l1", members=[ifpc1ir1,ir1])

# Connect nuc1 to ir2 over the wired net
link2 = request.Link("l2", members=[ifpc1ir2,ir2])

# Connect the two Iris radios over RF
rflink1 = request.RFLink("rf1")
rflink1.addNode(ir1)
rflink1.addNode(ir2)

# Print the RSpec to the enclosing page.
portal.context.printRequestRSpec()

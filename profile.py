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
FAROSHWTYPE = "faros-sfp"

# Create a Request object to start building the RSpec.
request = portal.context.makeRequestRSpec()
 
# Request a PC
pc1 = request.RawPC("pc1")
pc1.hardware_type = PCHWTYPE
pc1.disk_image = PCIMG
pc1.addService(pg.Execute(shell="sh", command="/usr/bin/sudo /local/repository/faros_start.sh"))
if1pc1 = pc1.addInterface("if1pc1", pg.IPv4Address("192.168.1.1", "255.255.255.0"))

# Request a Faros BS
mm1 = request.RawPC("mm1")
mm1.hardware_type = FAROSHWTYPE

# Connect nuc1 to ir1 over the wired net
link1 = request.Link("l1", members=[if1pc1,mm1])

# Print the RSpec to the enclosing page.
portal.context.printRequestRSpec()

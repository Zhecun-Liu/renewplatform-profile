"""A profile that instantiates a PC connected to a Skylark FAROS hub and connected radio chains.

Instructions:
The Faros hub and pc are connected via a private 10Gbps link. All Iris radios and the Faros hub should come up with address between 192.168.1.101 and 192.168.1.200.  These addresses are reachable by first logging in to "pc1".
"""

import geni.portal as portal
import geni.urn as urn
import geni.rspec.pg as pg
import geni.rspec.emulab as elab

# Resource strings
PCIMG = "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU16-64-STD"
PCHWTYPE = "d840"
FAROSHWTYPE = "faros_sfp"

# Create a Request object to start building the RSpec.
request = portal.context.makeRequestRSpec()
 
# Request a PC
pc1 = request.RawPC("pc1")
pc1.hardware_type = PCHWTYPE
pc1.disk_image = PCIMG
pc1.addService(pg.Execute(shell="sh", command="/usr/bin/sudo /local/repository/faros_start.sh"))
if1pc1 = pc1.addInterface("if1pc1", pg.IPv4Address("192.168.1.1", "255.255.255.0"))
if1pc1.bandwidth = 40 * 1000 * 1000

# Request a Faros BS.
mm1 = request.RawPC("mm1")
mm1.hardware_type = FAROSHWTYPE
mm1if1 = mm1.addInterface("mm1if1")
mm1if2 = mm1.addInterface("mm1if2")
mm1if3 = mm1.addInterface("mm1if3")
mm1if4 = mm1.addInterface("mm1if4")

# Connect the PC to the Faros BS.
lan1 = request.LAN("lan1")
lan1.addInterface(if1pc1)
lan1.addInterface(mm1if1)
lan1.addInterface(mm1if2)
lan1.addInterface(mm1if3)
lan1.addInterface(mm1if4)

# Print the RSpec to the enclosing page.
portal.context.printRequestRSpec()

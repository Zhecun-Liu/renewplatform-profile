"""A profile that instantiates PCs connected to a Skylark FAROS hub and connected radio chains.

Instructions:
The Faros hub and PCs are connected via a private 10Gbps link. All Iris radios and the Faros hub should come up with address between 192.168.1.101 and 192.168.1.200.  These addresses are reachable by first logging in to "pc0".
"""

import geni.portal as portal
import geni.urn as urn
import geni.rspec.pg as pg
import geni.rspec.emulab as elab

# Resource strings
PCIMG = None
FAROSHWTYPE = "faros_sfp"
IRISHWTYPE = "iris030"

pc = portal.Context()

# Create a Request object to start building the RSpec.
request = pc.makeRequestRSpec()

pc.defineParameter( "n", "Number of compute nodes",
                    portal.ParameterType.INTEGER, 1 )

pc.defineParameter( "type", "Compute node hardware type",
                    portal.ParameterType.STRING, "d430" )

params = pc.bindParameters()

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
lan1.setNoBandwidthShaping()
lan1.addInterface(mm1if1)
lan1.addInterface(mm1if2)
lan1.addInterface(mm1if3)
#lan1.addInterface(mm1if4)
lan1.addInterface(ir1if1)
lan1.addInterface(ir2if1)

# Request PCs
for i in range( params.n ):
    pc = request.RawPC( "pc" + str( i ) )
    pc.hardware_type = params.type
    pc.disk_image = PCIMG
    bs = request.RemoteBlockstore( "matlab" + str( i ), "/usr/local/MATLAB" )
    bs.dataset = "urn:publicid:IDN+emulab.net:powderprofiles+ltdataset+matlab-extra"
    bs.rwclone = True
    bslink = request.Link( "dslink" + str( i ) )
    bslink.addInterface( pc.addInterface( "dsiface" + str( i ) ) )
    bslink.addInterface( bs.interface )
    bslink.vlan_tagging = True
    bslink.best_effort = True
                         
    pc.addService(pg.Execute(shell="sh", command="/usr/bin/sudo /local/repository/faros_start.sh"))
    iface = pc.addInterface( "iface" + str( i ), pg.IPv4Address("192.168.1." + str( i + 1 ), "255.255.255.0"))
    lan1.addInterface( iface )

# Print the RSpec to the enclosing page.
portal.context.printRequestRSpec()

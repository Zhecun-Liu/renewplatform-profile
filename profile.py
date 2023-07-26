"""This profile instantiates a powder compute machine running Ubuntu 22.04 64-bit LTS. The machine can be connected to Skylark FAROS massive MIMO system comprised of a FAROS hub, a Faros massive MIMO Base Station.  An optional machine running the same base image can be separately connected to a set of Iris UEs (clients).  Additionally, the image has Intel oneapi, Flexran, and all other compilation dependencies of Agora preinstalled as an image backed dataset.

Since this profile includes multiple disk images it will can take up to 30 minutes to instantiate

An optional MATLAB installation is useful to run experiments on FAROS with RENEWLab demos. 

Instructions:
Do all your work (compile / running) from the /scratch directory.
sudo chsh -s /bin/bash YOURUSERNAME

- For more information on Agora please refer to our [github](https://github.com/Agora-wireless/Agora/wiki) and [wiki](https://github.com/Agora-wireless/Agora) sites.
- For more information on RENEWLab, see [RENEW documentation page](https://wiki.renew-wireless.org/)

"""

import geni.portal as portal
import geni.urn as urn
import geni.rspec.pg as pg
import geni.rspec.emulab as elab
import geni.rspec.emulab.spectrum as spectrum

# Resource strings
PCIMG = 'urn:publicid:IDN+emulab.net+image+argos-test:renew-u22-base'
MATLAB_DS_URN = 'urn:publicid:IDN+emulab.net:powdersandbox+imdataset+matlab2021ra-etc'
INTEL_LIBS_URN = 'urn:publicid:IDN+emulab.net:argos-test+imdataset+inteloneapi-u22'

RENEW_WD = "/scratch"
MATLAB_MP = "/usr/local/MATLAB"
STARTUP_SCRIPT = "/local/repository/renew_start.sh"
FAROSHWTYPE = "faros_sfp"
IRISHWTYPE = "iris030"

MMIMO_ARRAYS = ["", ("mmimo1-honors", "Honors"),
                ("mmimo1-meb", "MEB"),
                ("mmimo1-ustar", "USTAR")]

UE = ["", ("irisclients1-meb", "MEB Rooftop Clients Site 1 (2 Iris UEs)"),
      ("irisclients2-meb", "MEB Rooftop Clients Site 2 (2 Iris UEs)")]

PC_HWTYPE_SEL = [("d430", "D430 - Min"),
                 ("d740", "D740 - Mid"),
                 ("d840", "D840 - Max")]

#
# Profile parameters.
#
pc = portal.Context()

# Frequency/spectrum parameters
pc.defineStructParameter(
    "freq_ranges", "Range", [],
    multiValue=True,
    min=0,
    multiValueTitle="Frequency ranges for over-the-air operation.",
    members=[
        portal.Parameter(
            "freq_min",
            "Frequency Min",
            portal.ParameterType.BANDWIDTH,
            3540.0,
            longDescription="Values are rounded to the nearest kilohertz."
        ),
        portal.Parameter(
            "freq_max",
            "Frequency Max",
            portal.ParameterType.BANDWIDTH,
            3550.0,
            longDescription="Values are rounded to the nearest kilohertz."
        ),
    ])

# Array to allocate
pc.defineStructParameter(
    "mmimo_devices", "mMIMO Device", [],
    multiValue=True,
    min=0,
    multiValueTitle="Massive MIMO basestations to allocate.",
    members=[
        portal.Parameter(
            "mmimoid", "Array site location",
            portal.ParameterType.STRING, MMIMO_ARRAYS[0], MMIMO_ARRAYS
        ),
    ])

pc.defineStructParameter(
    "ue_devices", "UE Device", [],
    multiValue=True,
    min=0,
    multiValueTitle="UE clients to allocate.",
    members=[
        portal.Parameter(
            "ueid", "UE site location.",
            portal.ParameterType.STRING, UE[0], UE
        ),
    ])

#Typical Options
pc.defineParameter("matlabds", "Attach the Matlab dataset to the compute host.",
                   portal.ParameterType.BOOLEAN, True)

# third party libs
pc.defineParameter("intellibs", "Attach intel and 3rd party library datasets to the compute host.",
                   portal.ParameterType.BOOLEAN, True)

#Advanced options
pc.defineParameter("intelmountpt", "Mountpoint for 3rd party libraries and inteloneAPI",
                   portal.ParameterType.STRING, "/opt", advanced=True)

pc.defineParameter("INTEL_LIBS_URN", "URN of the 3rd party library dataset", 
                   portal.ParameterType.STRING,
                   INTEL_LIBS_URN, advanced=True)

pc.defineParameter("hubints", "Number of interfaces to attach on hub (def: 2)",
                   portal.ParameterType.INTEGER, 2, advanced=True,
                   longDescription="This can be a number between 1 and 4.")

pc.defineParameter("pchwtype", "PC Hardware Type",
                   portal.ParameterType.IMAGE,
                   PC_HWTYPE_SEL[2], PC_HWTYPE_SEL, advanced=True,
                   longDescription="Select the PC Hardware Type for RENEW software")

pc.defineParameter("fixedpc1id", "Fixed Node id (Optional)",
                   portal.ParameterType.STRING, "", advanced=True,
                   longDescription="Fix 'pc1' to this specific node.  Leave blank to allow for any available node of the correct type.")


# Bind and verify parameters.
params = pc.bindParameters()

for i, frange in enumerate(params.freq_ranges):
    if frange.freq_max - frange.freq_min < 1:
        perr = portal.ParameterError("Minimum and maximum frequencies must be separated by at least 1 MHz", ["freq_ranges[%d].freq_min" % i, "freq_ranges[%d].freq_max" % i])
        portal.context.reportError(perr)

if params.hubints < 1 or params.hubints > 4:
    perr = portal.ParameterError("Number of interfaces on hub to connect must be between 1 and 4 (inclusive).")
    portal.context.reportError(perr)

pc.verifyParameters()

# Create a Request object to start building the RSpec.
request = pc.makeRequestRSpec()

# VNC - initialize
request.initVNC()

# Request PC1
pc1 = request.RawPC("pc1")
pc1.startVNC()

if params.fixedpc1id:
    pc1.component_id=params.fixedpc1id
else:
    pc1.hardware_type = params.pchwtype
pc1.disk_image = PCIMG

#Setup Disk space for external libs and working directory
if params.intellibs:
    ilbspc1 = pc1.Blockstore( "intellibbspc1", params.intelmountpt )
    ilbspc1.dataset = params.INTEL_LIBS_URN
    ilbspc1.size = "32GB"
    ilbspc1.placement = "sysvol"

if params.matlabds:
    mlbs = pc1.Blockstore( "matlabpc1", MATLAB_MP )
    mlbs.dataset = MATLAB_DS_URN
    mlbs.placement = "nonsysvol"

bss1 = pc1.Blockstore("pc1wd", RENEW_WD)
#Matlab dataset ~30GB
#740 Only has 2x240GB Sata Drives (use 1 for sysvol)
if params.pchwtype == "d740":
    bss1.size = "200GB"
#840 has 4x1.6TB NVMEe SSD drives
#430 1 200GB SSD, 2x1TB 7200 rpm SATA
else:
    bss1.size = "900GB"
#place this on the nonsystem disk
bss1.placement = "nonsysvol"

if len(params.mmimo_devices):
    DISABLE_DHCP="false"
else:
    DISABLE_DHCP="true"

CHMOD_STARTUP = "sudo chmod 775 " + STARTUP_SCRIPT
STARTUP_COMMAND = STARTUP_SCRIPT + " " + DISABLE_DHCP
#Add the startup scripts
pc1.addService(pg.Execute(shell="sh", command=CHMOD_STARTUP))
pc1.addService(pg.Execute(shell="sh", command=STARTUP_COMMAND))
if1pc1 = pc1.addInterface("if1pc1", pg.IPv4Address("192.168.1.1", "255.255.255.0"))
# 40 Gbs good for d840 only
if params.pchwtype == "d840":
    if1pc1.bandwidth = 40 * 1000 * 1000 # 40 Gbps
else:
    if1pc1.bandwidth = 10 * 1000 * 1000 # 10 Gbps
if1pc1.latency = 0

# LAN connecting up everything (if needed).  Members are added below.
mmimolan = None

# Request a Faros BS.
if len(params.mmimo_devices):
    mmimolan = request.LAN("mmimolan")
    #mmimolan.best_effort = True
    mmimolan.latency = 0
    mmimolan.vlan_tagging = False
    mmimolan.setNoBandwidthShaping()
    #mmimolan.setNoInterSwitchLinks()
    mmimolan.addInterface(if1pc1)

    # Request all Faros BSes requested
    for i, mmimodev in enumerate(params.mmimo_devices):
        mm = request.RawPC("mm%d" % i)
        mm.component_id = mmimodev.mmimoid
        mm.hardware_type = FAROSHWTYPE
        for j in range(params.hubints):
            mmif = mm.addInterface()
            mmimolan.addInterface(mmif)

if len(params.ue_devices):
    uelan = mmimolan
    for i, uedev in enumerate(params.ue_devices):
        ue = request.RawPC("ir%d" % i)
        ue.component_id = uedev.ueid
        ue.hardware_type = IRISHWTYPE
        ueif = ue.addInterface()
        uelan.addInterface(ueif)

# Add frequency request(s)
for frange in params.freq_ranges:
    request.requestSpectrum(frange.freq_min, frange.freq_max, 100)

# Print the RSpec to the enclosing page.
pc.printRequestRSpec()

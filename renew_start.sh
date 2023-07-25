#!/bin/bash

RENEW_WD="scratch"
DISABLE_DHCP=$1

# Only run 1 time
STARTUP_FILE=/${RENEW_WD}/.startup_complete.me
if [ -f "$STARTUP_FILE" ]; then
#echo "$STARTUP_FILE exists exiting"
    exit 0
fi

MYWD=`dirname $0`
AGORAREPO="https://github.com/Agora-wireless/Agora.git"
PYFAROS="https://github.com/Agora-wireless/pyfaros"
RENEWLAB="https://github.com/renew-wireless/RENEWLab"

#Check to see if the mounts happened correctly
#/etc/fstab waiting here (/usr/local/matlab && /$RENEW_WD/ && /renew_dataset/ would be best to pass these paths into the script
loop_ctr=0
while [ $loop_ctr -lt 20 -a $(grep -csi $RENEW_WD /etc/fstab) -eq 0 ]
do
  echo "Working Directory ($RENEW_WD) does not exist yet"
  sleep 30
  loop_ctr=`expr $loop_ctr + 1`
done

if [ $(grep -csi $RENEW_WD /etc/fstab) -qe 0 ]
then
  echo "Working Directory ($RENEW_WD) does not exist"
  exit 1
fi

sudo apt-get -y update --allow-releaseinfo-change
if [ "$DISABLE_DHCP" != "true" ]
then
    IF1=`/usr/local/etc/emulab/findif -i 192.168.1.1`
    IF2=`/usr/local/etc/emulab/findif -i 192.168.1.2`

    if [ -z $IF1 ]
    then
        if [ -z $IF2 ]
        then
	    echo "Could not find interface for running dhcpd!"
	    exit 1
        else
            IF1=$IF2
        fi
    fi

    sudo apt-get -q -y install --reinstall isc-dhcp-server avahi-daemon || \
        { echo "Failed to install ISC DHCP server and/or Avahi daemon!" && exit 1; }

    sudo cp -f $MYWD/dhcpd.conf /etc/dhcp/dhcpd.conf || \
      { echo "Could not copy dhcp config file into place!" && exit 1; }

    sudo ed /etc/default/isc-dhcp-server << SNIP
/^INTERFACES/c
INTERFACES="$IF1"
.
w
SNIP

    if [ $? -ne 0 ]
    then
        echo "Failed to edit dhcp defaults file!"
        exit 1
    fi

    if [ ! -e /etc/init/isc-dhcp-server6.override ]
    then
        sudo bash -c 'echo "manual" > /etc/init/isc-dhcp-server6.override'
    fi

    sudo service isc-dhcp-server start || \
        { echo "Failed to start ISC dhcpd!" && exit 1; }
fi

#create service to disable turbo boost
echo "[Unit]
Description=Disable Turbo Boost on Intel CPU
 
[Service]
ExecStart=/bin/sh -c \"/usr/bin/echo 1 > \
/sys/devices/system/cpu/intel_pstate/no_turbo\"
ExecStop=/bin/sh -c \"/usr/bin/echo 0 > \
/sys/devices/system/cpu/intel_pstate/no_turbo\"
RemainAfterExit=yes
 
[Install]
WantedBy=sysinit.target" | sudo tee /etc/systemd/system/disable-turbo-boost.service
#reload
sudo systemctl daemon-reload
#disable turbo
sudo systemctl start disable-turbo-boost
sudo systemctl enable disable-turbo-boost

cd /${RENEW_WD}
sudo chown ${USER}:${GROUP} .
sudo chmod 775 .

mkdir dependencies
mkdir repos
cd repos

git clone --branch develop $AGORAREPO agora || \
    { echo "Failed to clone git repository: $AGORAREPO" && exit 1; }

git clone --branch develop $RENEWLAB RENEWLab || \
    { echo "Failed to clone git repository: $RENEWLAB" && exit 1; }

cd ../dependencies

# --- Armadillo (12.2.0)
wget http://sourceforge.net/projects/arma/files/armadillo-12.6.0.tar.xz
tar -xf armadillo-12.6.0.tar.xz
cd armadillo-12.6.0
cmake -DALLOW_OPENBLAS_MACOS=ON .
make -j`nproc`
sudo make install
sudo ldconfig
cd ../

# Install Soapy tools
# SoapySDR
git clone --branch soapy-sdr-0.8.1 --depth 1 --single-branch https://github.com/pothosware/SoapySDR.git
cd SoapySDR
mkdir -p build
cd build
cmake ../
make -j`nproc`
sudo make install
cd ../..
sudo ldconfig

#SoapyRemote
git clone --branch soapy-remote-0.5.2 --depth 1 --single-branch https://github.com/pothosware/SoapyRemote.git
cd SoapyRemote
mkdir -p build
cd build
cmake ../
make -j`nproc`
sudo make install
cd ../..
sudo ldconfig

#Iris drivers
git clone --branch bypass-socket-mod --depth 1 --single-branch https://github.com/Agora-wireless/sklk-soapyiris.git
cd sklk-soapyiris
mkdir -p build
cd build
cmake ../
make -j`nproc`
sudo make install
cd ../..
sudo ldconfig

git clone --branch python310_updates --depth 1 --single-branch $PYFAROS || \
    { echo "Failed to clone git repository: $PYFAROS" && exit 1; }
cd pyfaros/
./create_package.sh
pyfaros_version=`./create_version.sh`
cd dist
sudo pip3 install pyfaros-${pyfaros_version}.tar.gz --force-reinstall || \
    { echo "Failed to install Pyfaros!" && exit 1; }
sudo ldconfig

source /opt/intel/oneapi/setvars.sh --config="/opt/intel/oneapi/renew-config.txt"

#Enable the soapy sdr server for more robust device detection
sudo systemctl enable SoapySDRServer

# Install FlexRAN FEC SDK
cd /opt/FlexRAN-FEC-SDK-19-04/sdk
sudo rm -rf build-avx*

WIRELESS_SDK_TARGET_ISA="avx512"
export WIRELESS_SDK_TARGET_ISA
./create-makefiles-linux.sh
cd build-avx512-icc
make -j
sudo make install

WIRELESS_SDK_TARGET_ISA="avx2"
export WIRELESS_SDK_TARGET_ISA
./create-makefiles-linux.sh
cd build-avx2-icc
make -j

sudo ldconfig

#Make the saopy settings a lower priority
sudo mv /usr/local/lib/sysctl.d/SoapySDRServer.conf /usr/local/lib/sysctl.d/98-SoapySDRServer.conf
#Ethernet buffer sizes
echo -e '# Ethernet transport tuning\n# Socket Rx Buffer Max Size\nnet.core.rmem_max=536870912\n#Socket Send Buffer Max Size\nnet.core.wmem_max=536870912' | sudo tee /etc/sysctl.d/99-agora.conf
sudo sysctl --load /etc/sysctl.d/99-agora.conf

#Intel env vars
echo -e '#!/usr/bin/bash\nsource /opt/intel/oneapi/setvars.sh --config="/opt/intel/oneapi/renew-config.txt"' | sudo tee /etc/profile.d/10-inteloneapivars.sh
#non-login consoles
echo -e '\n#Gen intel env vars\nsource /opt/intel/oneapi/setvars.sh --config="/opt/intel/oneapi/renew-config.txt"' | sudo tee -a /etc/bash.bashrc

#User ownership of the working directory
CHOWN_WD='#2sudo chown -R $(id -u):$(id -g) '/${RENEW_WD}/' > /dev/null 2>&1'
#echo -e '#!/usr/bin/bash\nsudo chown -R $(id -u):$(id -g) '"/${RENEW_WD}/ > /dev/null 2>&1" | sudo tee /etc/profile.d/11-wd_owner.sh
#non-login consoles
#echo -e '#Set user in control of working dir\nsudo chown -R $(id -u):$(id -g) '"/${RENEW_WD}/ > /dev/null 2>&1" | sudo tee -a /etc/bash.bashrc

echo -e -n '#!/usr/bin/bash\n#sudo chown -R $(id -u):$(id -g) ' | sudo tee /etc/profile.d/11-wd_owner.sh
echo "/${RENEW_WD}/ > /dev/null 2>&1" | sudo tee -a /etc/profile.d/11-wd_owner.sh
echo $CHOWN_WD | sudo tee -a /etc/profile.d/11-wd_owner.sh

#non-login consoles
#echo -e -n '#Set user in control of working dir\nsudo chown -R $(id -u):$(id -g) ' | sudo tee -a /etc/bash.bashrc
#echo "/${RENEW_WD}/ > /dev/null 2>&1" | sudo tee -a /etc/bash.bashrc


#Build RenewLab
cd /${RENEW_WD}/repos/RENEWLab/CC/Sounder/mufft/
git submodule update --init
cmake -DCMAKE_POSITION_INDEPENDENT_CODE=ON ./ && make -j
cd ../
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DLOG_LEVEL=info && make -j
cd /${RENEW_WD}

#Build Agora
cd /${RENEW_WD}/repos/agora
mkdir build
cd build
cmake .. -DRADIO_TYPE=SOAPY_IRIS
make -j
cd /${RENEW_WD}

#Modify the grub file to isolate the cpu cores turn off multithreading, cpu mitigations, and sets hugepage support, iommu enabled for dpdk vfio.
global_options="default_hugepagesz=1G hugepagesz=1G hugepages=4 mitigations=off nosmt intel_iommu=on iommu=pt cpufreq.default_governor=performance"
#d840 specific cpu setup
isolcpus_d840="isolcpus=1-3,5-7,9-11,13-15,17-19,21-23,25-27,29-31,33-35,37-39,41-43,45-47,49-51,53-55,57-59,61-63"
irqaffinity_d840="irqaffinity=0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60"
#d740 specific cpu setup
isolcpus_d740="isolcpus=1,3,5,7,9,11,13,15,17,19,21,23"
irqaffinity_d740="irqaffinity=0,2,4,6,8,10,12,14,16,18,20,22"

#Determine the correct configuration
cpu_count=`nproc --all`
if [ $cpu_count -eq 64 ]; then
  echo "Detected D840"
  isolcpus=$isolcpus_d840
  irqaffinity=$irqaffinity_d840
elif [ $cpu_count -eq 24 ]; then
  echo "Detected D740"
  isolcpus=$isolcpus_d740
  irqaffinity=$irqaffinity_d740
else
  echo "CPU TYPE NOT SUPPORTED.  Found $cpu_count CPUS - Defaulting to d740"
  isolcpus=$isolcpus_d740
  irqaffinity=$irqaffinity_d740
fi

sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$global_options $isolcpus $irqaffinity\"/1" /etc/default/grub
sudo update-grub
#remove ondemand cpu freq scaling
sudo systemctl disable ondemand
#Display active governor
#cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
#Display pc mhz
#lscpu |grep "CPU MHz"

#output a json configuration file
cd /${RENEW_WD}
python3 -m pyfaros.discover --json-out
sleep 1
python3 -m pyfaros.discover --json-out
touch $STARTUP_FILE

sudo shutdown -r +1 "Rebooting with modified kernel parameters"
exit $?

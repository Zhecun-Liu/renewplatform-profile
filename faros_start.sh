#!/bin/bash

IF1=`/usr/local/etc/emulab/findif -i 192.168.1.1`
MYWD=`dirname $0`
SCRATCH="/scratch"
REPO="https://github.com/renew-wireless/RENEWLab.git"
PYFAROS="https://github.com/skylarkwireless/pyfaros.git"

if [ -z $IF1 ]
then
	echo "Could not find interface for running dhcpd!"
	exit 1
fi

sudo apt-get -q update && \
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


cd $SCRATCH
sudo chown ${USER}:${GROUP} .
sudo chmod 775 .

mkdir dependencies
mkdir repos
cd repos

git clone --branch master $REPO RENEWLab || \
    { echo "Failed to clone git repository: $REPO" && exit 1; }

cd ../dependencies

# --- Armadillo (10.7.4)
echo "Installing Armadillo Library"
wget http://sourceforge.net/projects/arma/files/armadillo-10.7.4.tar.xz
tar -xf armadillo-10.7.4.tar.xz
cd armadillo-10.7.4
cmake -DALLOW_OPENBLAS_MACOS=ON .
make -j`nproc`
sudo make install
sudo ldconfig
cd ../

# Install Soapy tools
# SoapySDR
echo "Installing SoapySDR"
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
echo "Installing SoapyRemote"
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
echo "Installing SoapyIris"
git clone --branch soapy-iris-2020.02.0.1 --depth 1 --single-branch https://github.com/skylarkwireless/sklk-soapyiris.git
cd sklk-soapyiris
mkdir -p build
cd build
cmake ../
make -j`nproc`
sudo make install
cd ../..
sudo ldconfig

# Update pip3
echo "Updating Pip"
sudo pip3 install --upgrade pip

# Install Pyfaros
echo "Installing Pyfaros"
git clone --branch v1.4 --depth 1 --single-branch $PYFAROS || \
    { echo "Failed to clone git repository: $PYFAROS" && exit 1; }
cd pyfaros/
./create_package.sh
pyfaros_version=`./create_version.sh`
cd dist
sudo pip3 install pyfaros-${pyfaros_version}.tar.gz --ignore-installed || \
    { echo "Failed to install Pyfaros!" && exit 1; }
cd ../..
sudo ldconfig

#export PYTHONPATH=/usr/local/lib/python3/dist-packages/:"${PYTHONPATH}"
#echo /usr/local/lib/python3/dist-packages/ | sudo tee /usr/lib/python3/dist-packages/SoapySDR.pth

#Build RenewLab
echo "Building RENEWLab (Sounder)"
cd $SCRATCH/repos/RENEWLab/CC/Sounder/mufft/
git submodule update --init
cmake -DCMAKE_POSITION_INDEPENDENT_CODE=ON ./ && make -j
cd ../
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DLOG_LEVEL=info && make -j
cd $SCRATCH

#Make the saopy settings a lower priority
sudo mv /usr/local/lib/sysctl.d/SoapySDRServer.conf /usr/local/lib/sysctl.d/98-SoapySDRServer.conf
#Ethernet buffer sizes
echo -e '# Ethernet transport tuning\n# Socket Rx Buffer Max Size\nnet.core.rmem_max=536870912\n#Socket Send Buffer Max Size\nnet.core.wmem_max=536870912' | sudo tee /etc/sysctl.d/99-renew.conf
sudo sysctl --load /etc/sysctl.d/99-renew.conf

# Run command twice in case of board discovery transient issue
python3 -m pyfaros.discover --json-out
sleep 1
python3 -m pyfaros.discover --json-out

echo -e '#!/usr/bin/bash\nsudo chown -R $(id -u):$(id -g) /scratch/ > /dev/null 2>&1' | sudo tee /etc/profile.d/11-scratchowner.sh
cd $SCRATCH

exit $?

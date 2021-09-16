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
mkdir dev_repos
cd dev_repos

git clone --branch master $REPO || \
    { echo "Failed to clone git repository: $REPO" && exit 1; }

cd ../dependencies

# --- Armadillo (10.6.2)
wget http://sourceforge.net/projects/arma/files/armadillo-10.6.2.tar.xz
tar -xf armadillo-10.6.2.tar.xz
cd armadillo-10.6.2
cmake -DALLOW_OPENBLAS_MACOS=ON .
make -j`nproc`
sudo make install
sudo ldconfig

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
git clone --branch soapy-iris-2020.02.0.1 --depth 1 --single-branch https://github.com/skylarkwireless/sklk-soapyiris.git
cd sklk-soapyiris
mkdir -p build
cd build
cmake ../
make -j`nproc`
sudo make install
cd ../..
sudo ldconfig

git clone --branch v1.1 --depth 1 --single-branch $PYFAROS || \
    { echo "Failed to clone git repository: $PYFAROS" && exit 1; }
cd pyfaros/
./create_package.sh
cd dist && sudo pip3 install pyfaros-0.0.5+efa49b90.tar.gz --ignore-installed || \
    { echo "Failed to install Pyfaros!" && exit 1; }

#export PYTHONPATH=/usr/local/lib/python3/dist-packages/:"${PYTHONPATH}"
#echo /usr/local/lib/python3/dist-packages/ | sudo tee /usr/lib/python3/dist-packages/SoapySDR.pth
sudo ldconfig

# Run command twice in case of board discovery transient issue
python3 -m pyfaros.discover --json-out
sleep 1
python3 -m pyfaros.discover --json-out
cd $SCRATCH

exit $?

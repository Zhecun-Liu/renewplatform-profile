#!/bin/bash

IF1=`/usr/local/etc/emulab/findif -i 192.168.1.1`
MYWD=`dirname $0`
SCRATCH="/scratch"
REPO="https://github.com/renew-wireless/RENEWLab.git"

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
git clone $REPO || \
    { echo "Failed to clone git repository: $REPO" && exit 1; }

cd RENEWLab
sudo ./install_soapy.sh || \
    { echo "Failed to install Soapy!" && exit 1; }

sudo ./install_pylibs.sh || \
    { echo "Failed to install Python libraries!" && exit 1; }

sudo ./install_cclibs.sh || \
    { echo "Failed to install C libraries!" && exit 1; }

sudo apt-get -q -y install python3-pip
sudo pip3 install --upgrade pip

wget --user sklk --password LightHouse2053 https://files.sklk.us/pyfaros/pyfaros-0.0.5%2Bab605729.tar.gz || \
    { echo "Failed to retrieve Pyfaros Package!" && exit 1; }

sudo pip3 install pyfaros-0.0.5+ab605729.tar.gz --ignore-installed || \
    { echo "Failed to install Pyfaros!" && exit 1; }

exit $?

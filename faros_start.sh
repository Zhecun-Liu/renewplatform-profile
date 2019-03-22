#!/bin/bash

IF1=`/usr/local/etc/emulab/findif -i 192.168.1.1`
MYWD=`dirname $0`

if [ -z $IF1 ]
then
	echo "Could not get interface for running dhcpd!"
	exit 1
fi

apt-get -q update && \
    apt-get -q -y install --reinstall isc-dhcp-server avahi-daemon || \
    { echo "Failed to install ISC DHCP server and/or Avahi daemon!" && exit 1; }

cp -f $MYWD/dhcpd.conf /etc/dhcp/dhcpd.conf || \
  { echo "Could not copy dhcp config file into place!" && exit 1; }

ed /etc/default/isc-dhcp-server << SNIP
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
    echo "manual" > /etc/init/isc-dhcp-server6.override
fi

service isc-dhcp-server start || \
    { echo "Failed to start ISC dhcpd!" && exit 1; }

cd $MYWD
git submodule update --init || \
    { echo "Failed to update git submodules!" && exit 1; }

./renew-software/install_soapy.sh || \
    {echo "Failed to install Soapy!" && exit 1; }

exit $?

#!/bin/bash

IF1=`/usr/local/etc/emulab/findif -i 192.168.1.1`
IF2=`/usr/local/etc/emulab/findif -i 192.168.2.1`

MYWD=`dirname $0`

if [ -z $IF1 -o -z $IF2 ]
then
	echo "Could not get interfaces for running dhcpd!"
	exit 1
fi

apt-get update && apt-get install isc-dhcp-server || \
  { echo "Failed to install ISC DHCP server!" && exit 1; }

cp -f $MYWD/dhcpd.conf /etc/dhcpd/dhcpd.conf || \
  { echo "Could not copy dhcp config file into place!" && exit 1; }

ed /etc/default/isc-dhcp-server << SNIP
/^INTERFACES/c
INTERFACES="$IF1 $IF2"
.
w
SNIP

if [ $? -ne 0 ]
then
    echo "Failed to edit dhcp defaults file!"
    exit 1
fi

service isc-dhcp-server start
exit $?

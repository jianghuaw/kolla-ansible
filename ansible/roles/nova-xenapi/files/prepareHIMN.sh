#!/bin/bash
##############################
# obsoleted by prepareHIMN.py
##############################

# We can get the proper interface by detecting it via the HINM ip,
# or put it into the globals.yml as an configure item.
interface=eth3
cat >/etc/sysconfig/network-scripts/ifcfg-$interface <<EOF
DEVICE="$interface"
IPV6INIT="no"
BOOTPROTO="dhcp"
DEFROUTE=no
ONBOOT="yes"
EOF

ifdown $interface

ifup $interface

# TODO: forwarding IP for storage and API interfaces

# TODO: Prepare dom0 with proper routing.

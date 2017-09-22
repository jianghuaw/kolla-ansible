#!/bin/bash

XS_DOM0_IPTABLES_CHAIN="XenServerOpenStack"

DOM0_OVSDB_PORT=${DOM0_OVSDB_PORT:-"6640"}
DOM0_VXLAN_PORT=${DOM0_VXLAN_PORT:-"4789"}

function run_in_domzero() {
    sudo -u root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@169.254.0.1 "$@"
}

function config_dom0_iptables {

    # Remove restriction on linux bridge in Dom0 so security groups
    # can be applied to the interim bridge-based network.
    run_in_domzero "rm -f /etc/modprobe.d/blacklist-bridge*"

    # Save errexit setting
    _ERREXIT_XENSERVER=$(set +o | grep errexit)
    set +o errexit
    set -x

    # Check Dom0 internal chain for Neutron, add if not exist
    run_in_domzero "iptables -t filter -L $XS_DOM0_IPTABLES_CHAIN"
    local chain_result=$?
    if [ "$chain_result" != "0" ]; then
        run_in_domzero "iptables -t filter --new $XS_DOM0_IPTABLES_CHAIN"
        run_in_domzero "iptables -t filter -I INPUT -j $XS_DOM0_IPTABLES_CHAIN"
    fi

    # Check iptables for remote ovsdb connection, add if not exist
    run_in_domzero "iptables -t filter -C $XS_DOM0_IPTABLES_CHAIN -p tcp -m tcp --dport $DOM0_OVSDB_PORT -j ACCEPT"
    local remote_conn_result=$?
    if [ "$remote_conn_result" != "0" ]; then
        run_in_domzero "iptables -t filter -I $XS_DOM0_IPTABLES_CHAIN -p tcp --dport $DOM0_OVSDB_PORT -j ACCEPT"
    fi

    # Check iptables for VxLAN, add if not exist
    run_in_domzero "iptables -t filter -C $XS_DOM0_IPTABLES_CHAIN -p udp -m multiport --dports $DOM0_VXLAN_PORT -j ACCEPT"
    local vxlan_result=$?
    if [ "$vxlan_result" != "0" ]; then
        run_in_domzero "iptables -t filter -I $XS_DOM0_IPTABLES_CHAIN -p udp -m multiport --dport $DOM0_VXLAN_PORT -j ACCEPT"
    fi

    # routing service packets via HIMN
    # TODO(jianghua): change the hard-coded net and gw ip to using the parameter passed from ansible.
    run_in_domzero "/sbin/route -n | grep 192.168.1.0 >/dev/null"
    if [ $? -ne 0 ]; then
        run_in_domzero "/sbin/route add -net 192.168.1.0 netmask 255.255.255.0 gw 169.254.0.2"
    fi

    # Restore errexit setting
    $_ERREXIT_XENSERVER
}

config_dom0_iptables

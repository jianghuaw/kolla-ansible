#!/bin/bash

XS_DOM0_IPTABLES_CHAIN="XenServerOpenStack"

DOM0_OVSDB_PORT=${DOM0_OVSDB_PORT:-"6640"}
DOM0_VXLAN_PORT=${DOM0_VXLAN_PORT:-"4789"}

function run_in_domzero() {
    sudo -u root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@169.254.0.1 "$@"
}

# Remove Dom0 firewall rules created by this plugin
function cleanup_dom0_iptables {

    # Save errexit setting
    _ERREXIT_XENSERVER=$(set +o | grep errexit)
    set +o errexit

    run_in_domzero "iptables -t filter -L $XS_DOM0_IPTABLES_CHAIN"
    local chain_result=$?
    if [ "$chain_result" == "0" ]; then
        run_in_domzero "iptables -t filter -F $XS_DOM0_IPTABLES_CHAIN"
        run_in_domzero "iptables -t filter -D INPUT -j $XS_DOM0_IPTABLES_CHAIN"
        run_in_domzero "iptables -t filter -X $XS_DOM0_IPTABLES_CHAIN"
    fi

    run_in_domzero "/sbin/route -n | grep 169.254.0.2 >/dev/null"
    if [ $? -eq 0 ]; then
        run_in_domzero "/sbin/route del -net 192.168.1.0 netmask 255.255.255.0 gw 169.254.0.2"
    fi

    # Restore errexit setting
    $_ERREXIT_XENSERVER
}

cleanup_dom0_iptables

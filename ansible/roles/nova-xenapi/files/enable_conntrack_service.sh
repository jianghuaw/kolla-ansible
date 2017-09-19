#!/bin/bash

function run_in_domzero() {
    sudo -u root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@169.254.0.1 "$@"
}

xs_host=$(run_in_domzero xe host-list --minimal)
xs_ver_major=$(run_in_domzero xe host-param-get uuid=$xs_host param-name=software-version param-key=product_version_text_short | cut -d'.' -f 1)
CONNTRACKD=$(run_in_domzero ls /usr/sbin/conntrackd 2>/dev/null)

if [ $xs_ver_major -gt 6 ]; then
    # Only support conntrack-tools in Dom0 with XS7.0 and above
    if [ -z "$CONNTRACKD" ]; then
        run_in_domzero sed -i s/#baseurl=/baseurl=/g /etc/yum.repos.d/CentOS-Base.repo
        centos_ver=$(run_in_domzero yum version nogroups |grep Installed | cut -d' ' -f 2 | cut -d'/' -f 1 | cut -d'-' -f 1)
        run_in_domzero yum install -y --enablerepo=base --releasever=$centos_ver conntrack-tools
        # Backup conntrackd.conf after install conntrack-tools, use the one with statistic mode
        run_in_domzero mv /etc/conntrackd/conntrackd.conf /etc/conntrackd/conntrackd.conf.back
        conntrack_conf=$(run_in_domzero find /usr/share/doc -name conntrackd.conf |grep stats)
        run_in_domzero cp $conntrack_conf /etc/conntrackd/conntrackd.conf
    fi
    run_in_domzero service conntrackd restart
fi

#!/bin/bash
## install dom0 plugins
TMP_DIR='/tmp/plugins_dom0'
TARGET_DIR='/etc/xapi.d/plugins/'
SOURCE_DIR=/var/lib/kolla/venv/lib/python2.7/site-packages/os_xenapi/dom0/etc/xapi.d/plugins
if [ -f $TMP_DIR ]; then
    rm -rf $TMP_DIR
fi

mkdir -p $TMP_DIR

docker cp nova_compute:$SOURCE_DIR/ $TMP_DIR/

scp -o 'StrictHostKeyChecking=no' $TMP_DIR/plugins* root@169.254.0.1:$TARGET_DIR/
ssh -o 'StrictHostKeyChecking=no' root@169.254.0.1 chmod +x $TARGET_DIR/*

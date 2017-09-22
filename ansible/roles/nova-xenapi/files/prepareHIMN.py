#!/usr/bin/env python
import logging
import getopt
import os
import subprocess
import tempfile
import netifaces
import sys


LOG = logging.getLogger('HIMN')

HIMN_IP = '169.254.0.1'
XS_RSA = '/root/.ssh/id_rsa'


class ExecutionError(Exception):
    pass

def detect_himn(eths=None):
    if eths is None:
        eths = netifaces.interfaces()
    for eth in eths:
        ip = netifaces.ifaddresses(eth).get(netifaces.AF_INET)
        if ip is None:
            continue
        himn_local = ip[0]['addr']
        himn_xs = '.'.join(himn_local.split('.')[:-1] + ['1'])
        if HIMN_IP == himn_xs:
            return eth, ip
    return None, None

def ssh(host, username, *cmd, **kwargs):
    cmd = map(str, cmd)

    return execute('ssh', '-i', XS_RSA,
                   '-o', 'StrictHostKeyChecking=no',
                   '%s@%s' % (username, host), *cmd, **kwargs)

def detailed_execute(*cmd, **kwargs):
    cmd = map(str, cmd)
    _env = kwargs.get('env')
    env_prefix = ''
    if _env:
        env_prefix = ''.join(['%s=%s ' % (k, _env[k]) for k in _env])

        env = dict(os.environ)
        env.update(_env)
    else:
        env = None
    LOG.info(env_prefix + ' '.join(cmd))
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE,  # nosec
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, env=env)

    prompt = kwargs.get('prompt')
    if prompt:
        (out, err) = proc.communicate(prompt)
    else:
        (out, err) = proc.communicate()

    if out:
        # Truncate "\n" if it is the last char
        out = out.strip()
        LOG.debug(out)
    if err:
        LOG.info(err)

    if proc.returncode is not None and proc.returncode != 0:
        if proc.returncode in kwargs.get('allowed_return_codes', [0]):
            LOG.info('Swallowed acceptable return code of %d',
                     proc.returncode)
        else:
            LOG.warn('proc.returncode: %s', proc.returncode)
            raise ExecutionError(err)

    return proc.returncode, out, err


def execute(*cmd, **kwargs):
    _, out, _ = detailed_execute(*cmd, **kwargs)
    return out

def main(argv):
    opts, args = getopt.getopt(argv, "i:")
    for opt, arg in opts:
        if opt == '-i':
            network_interface = arg
            print("network_interface=%s" % network_interface)
        else:
            print('Unsupported option used: %s' % opt)
            sys.exit(1)

    eth, ip = detect_himn()
    if not ip:
        # TODO (jianghuaw): this depends on the host VM has PV driver installed.
        # Otherwise, the ip may be not populated. Then need use xenstore to get
        # the eth or ip.
        #
        pass
    # populate the ifcfg file for HIMN interface, so that it will always get ip in the future.
    ifcfg_file = '/etc/sysconfig/network-scripts/ifcfg-%s' % eth 
    s = ('DEVICE="{eth}"\n'
         'IPV6INIT="no"\n'
         'BOOTPROTO="dhcp"\n'
         'DEFROUTE=no\n'
         'ONBOOT="yes"\n'.format(eth=eth))
    with open(ifcfg_file, 'w') as f:
        f.write(s)

    # allow traffic from HIMN and forward traffic
    execute('/usr/bin/touch', '/tmp/test_by_himn')
    execute('iptables', '-t', 'nat', '-A', 'POSTROUTING',
            '-o', network_interface, '-j', 'MASQUERADE')
    execute('iptables', '-A', 'FORWARD',
            '-i', network_interface, '-o', eth,
            '-m', 'state', '--state', 'RELATED,ESTABLISHED',
            '-j', 'ACCEPT')
    execute('iptables', '-A', 'FORWARD',
            '-i', eth, '-o', network_interface,
            '-j', 'ACCEPT')
    execute('iptables', '-A', 'INPUT', '-i', eth, '-j', 'ACCEPT')
    execute('iptables', '-t', 'filter', '-S', 'FORWARD')
    execute('iptables', '-t', 'nat', '-S', 'POSTROUTING')


if __name__ == '__main__':
    main(sys.argv[1:])

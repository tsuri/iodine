#!/usr/bin/python3.4

import subprocess
import unittest
import re
import functools
import yaml
from nose.tools import eq_ as eq

def command(cmd):
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
    (out, err) = proc.communicate()
    return out.decode('utf-8')
    
def ssh_command(ip_addr, ssh_cmd):
    ssh_target = "infra@%s" % ip_addr
#    cmd="ssh infra@%s %s" % (ip_addr, ssh_cmd)
    cmd="ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no infra@%s %s" % (ip_addr, ssh_cmd)
    return command(cmd)

@functools.lru_cache(1)
def get_vms():
    machines = {}
    states = '|'.join(['aborted', 'poweroff', 'paused', 'running', 'not created'])
    for line in command("vagrant status").split('\n'):
        match = re.match(r'([a-z0-9]+)\s+(%s) \(virtualbox\)' % states, line)
        if match:
            machines[match.group(1)] = match.group(2)

    return machines

def merge(user, default):
    if isinstance(user,dict) and isinstance(default,dict):
        for k,v in default.items():
            if k not in user:
                user[k] = v
            else:
                user[k] = merge(user[k],v)
    return user

def read_yaml(file):
    with open(file, 'r') as stream:
        try:
            return yaml.load(stream)
        except yaml.YAMLError as exc:
            print(exc)

@functools.lru_cache(1)
def get_cluster_definition():
    return merge(read_yaml('cluster.cfg'), read_yaml('cluster_default.cfg'))

def get_servers_definition():
    return get_cluster_definition()['servers']

# should come from cluster config; for now keep in sync w/ utility.rb
def machine_ip(type,i):
    base = {'c': 9, 'e': 14, 'm': 19, 'w': 24}
    return "172.28.8.%s" % str(base[type]+i)

from functools import partial, update_wrapper
def testGenerator():
    for i in range(10):
        func = partial(test_x)
        # make decorator with_setup() work again
        update_wrapper(func, test_x)
        func.description = "nice test name %s" % i
        testGenerator.__name__ = "nice test name %s" % i
        yield func

def test_x():
    pass

def test_m():
    servers = get_servers_definition()
    machines = get_vms()
    for server in servers:
        count = servers[server]['count']
        reserve = servers[server].get('reserve', 0)
        for i in range(1,count+1):
            type = server[0:1]
            name = "%s%02d" % (type, i)
            yield _test_m, name, machine_ip(type, i)

# def generate_tests(f):
#     servers = get_servers_definition()
#     machines = get_vms()
#     for server in servers:
#         count = servers[server]['count']
#         reserve = servers[server].get('reserve', 0)
#         for i in range(1,count+1):
#             type = server[0:1]
#             name = "%s%02d" % (type, i)
#             yield f, name, machine_ip(type, i)
    
#def test_m1():
#    generate_tests(_test_m)
    
def _test_m(server, ip):
    try:
        eq(ssh_command(ip, "hostname").strip(), server)
        eq(ssh_command(server, "hostname").strip(), server)
    except AssertionError:
        raise

def test_flannel():
    servers = get_servers_definition()
    machines = get_vms()
    for server in servers:
        count = servers[server]['count']
        reserve = servers[server].get('reserve', 0)
        for i in range(1,count+1):
            type = server[0:1]
            name = "%s%02d" % (type, i)
            yield _test_flannel, name, machine_ip(type, i)

def _test_flannel(server, ip):
    try:
        subnets = ssh_command("c01", "etcdctl ls /coreos.com/network/subnets/")
        out = ssh_command(ip, "ifconfig flannel0|grep -w inet").strip()
        match = re.match(r'inet ([0-9.]+)\s+netmask ([0-9.]+)\s+.*$', out)
        if match:
            public_ip_line = ssh_command("c01", "etcdctl get /coreos.com/network/subnets/%s-24" % match.group(1))
            match_ip = re.match(r'{"PublicIP":"([0-9.]+)"}', public_ip_line.strip())
            eq(ip, match_ip.group(1))
            eq(match.group(2), "255.255.0.0")
        else:
            raise AssertionError
        # match = re.match(r'([a-z0-9]+)\s+(%s) \(virtualbox\)' % states, line)
        # if match:
        #     machines[match.group(1)] = match.group(2)
        # print(out)
#        eq(out.strip(),"XXX")
    except AssertionError:
        raise

# def test_machines():
#     servers = get_servers_definition()
#     machines = get_vms()
#     for server in servers:
#         count = servers[server]['count']
#         reserve = servers[server].get('reserve', 0)
#         for i in range(1,count+1):
#             type = server[0:1]
#             name = "%s%02d" % (type, i)
#             assert machines[name] == 'running', "%s running" % name
#             hostname = ssh_command(machine_ip(type, i), "hostname").strip()
#             assert hostname == name, "hostname is %s (found %s)" % (name, hostname)
            
    #     assert machines[m] == 'running'
    
# class TestCoreos(unittest.TestCase):

# #    def test_machines(self):
        
#     def test_ssh(self):
#         hostname = ssh_command("172.28.8.25", "hostname").strip()
#         self.assertEqual(hostname, "w01")
    
#     def test_upper(self):
#         self.assertEqual('foo'.upper(), 'FOO')

#     def test_isupper(self):
#         self.assertTrue('FOO'.isupper())
#         self.assertFalse('Foo'.isupper())

#     def test_split(self):
#         s = 'hello world'
#         self.assertEqual(s.split(), ['hello', 'world'])
#         # check that s.split fails when the separator is not a string
#         with self.assertRaises(TypeError):
#             s.split(2)

#if __name__ == '__main__':
#    test_machines()
#    print(get_servers_definition())
# #    print ssh_command("172.28.8.25", "hostname")
#     print (get_vms())
#     print (get_vms())
# #    unittest.main()

# -*- mode: ruby -*-

require 'fileutils'
require 'pp'                    # debugging only
require 'net/http'
require 'open-uri'
require 'json'
require 'date'
require 'erb'
require 'etc'

required_plugins = %w(vagrant-triggers)
required_plugins.push('vagrant-timezone')

required_plugins.each do |plugin|
  need_restart = false
  unless Vagrant.has_plugin? plugin
    system "vagrant plugin install #{plugin}"
    need_restart = true
  end
  exec "vagrant #{ARGV.join(' ')}" if need_restart
end

puts ">>> CPU #{Etc.nprocessors}"

Vagrant.require_version ">= 1.6.0"
VAGRANTFILE_API_VERSION = "2"

require_relative "vagrant_functions/utility.rb"

generateSSLCertificates()


$cluster = getClusterConfig(['cluster_default.cfg', 'cluster.cfg'])

# pp $cluster

# configureUserData(3)

REQUIRED_BINARIES_FOR_MASTER = ['kube-apiserver', 'kube-controller-manager', 'kube-scheduler']
REQUIRED_BINARIES_FOR_NODES = ['kube-proxy', 'kubelet']
REQUIRED_BINARIES = REQUIRED_BINARIES_FOR_MASTER + REQUIRED_BINARIES_FOR_NODES

# ./binaries should be in a variable, used also below
downloadKubernetesBinaries("./binaries", $cluster['kubernetes_version'], REQUIRED_BINARIES)

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # always use host timezone in VMs
  config.timezone.value = :host

  config.vm.box = "coreos-%s" % $cluster['coreos_channel']
  config.vm.box_url = "https://storage.googleapis.com/%s.release.core-os.net/amd64-usr/%s/coreos_production_vagrant.json" % [$cluster['coreos_channel'], $cluster['coreos_version']]
  config.vm.box_version = $cluster['coreos_version']
  config.vm.box_check_update = false # we handle updates by ourselves, mimicking baremetal
  
  config.vm.provider :virtualbox do |v|
    # On VirtualBox, we don't have guest additions or a functional vboxsf
    # in CoreOS, so tell Vagrant that so it can be smarter.
    v.check_guest_additions = false
    v.functional_vboxsf     = false
  end

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

#  configureUserData(3)          # this is not the size of the etcd subcluser, this is coreOS

  ($cluster['servers'].keys).each do |type|
    puts "Configuring #{type} nodes"
    provisionServers("./binaries", config, type, $cluster['servers'][type])
  end
end

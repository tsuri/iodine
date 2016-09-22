# -*- mode: ruby -*-

require 'fileutils'
require 'pp'                    # debugging only
require 'net/http'
require 'open-uri'
require 'json'
require 'date'
require 'erb'
require 'etc'

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

  configureUserData(3)          # this is not the size of the etcd subcluser, this is coreOS

#  pp $cluster
  
  ($cluster['servers'].keys).each do |type|
    provisionServers("./binaries", config, type, $cluster['servers'][type])
  end
end

# # TODO(mav) put this somewhere else, cluster related
# # Generate root CA
# system("mkdir -p ssl && ./scripts/init-ssl-ca ssl") or abort ("failed generating SSL artifacts")

# # Generate admin key/cert
# system("./scripts/init-ssl ssl admin kube-admin") or abort("failed generating admin SSL artifacts")

# def provisionMachineSSL(machine,certBaseName,cn,ipAddrs)
#   tarFile = "ssl/#{cn}.tar"
#   ipString = ipAddrs.map.with_index { |ip, i| "IP.#{i+1}=#{ip}"}.join(",")
#   system("./scripts/init-ssl ssl #{certBaseName} #{cn} #{ipString}") or abort("failed generating #{cn} SSL artifacts")
#   machine.vm.provision :file, :source => tarFile, :destination => "/tmp/ssl.tar"
#   machine.vm.provision :shell, :inline => "mkdir -p /etc/kubernetes/ssl && tar -C /etc/kubernetes/ssl -xf /tmp/ssl.tar", :privileged => true
# end

# Vagrant.configure("2") do |config|
#   config.ssh.insert_key = false
#   config.ssh.forward_agent = true

#   config.vm.box = "coreos-%s" % $update_channel
#   config.vm.box_url = "https://storage.googleapis.com/%s.release.core-os.net/amd64-usr/%s/coreos_production_vagrant.json" % [$update_channel, $image_version]

#   config.vm.provider :virtualbox do |v|
#     # On VirtualBox, we don't have guest additions or a functional vboxsf
#     # in CoreOS, so tell Vagrant that so it can be smarter.
#     v.check_guest_additions = false
#     v.functional_vboxsf     = false
#   end

#   # plugin conflict
#   if Vagrant.has_plugin?("vagrant-vbguest") then
#     config.vbguest.auto_update = false
#   end

#   ($cluster.keys).each do |type|
#     base_count = $cluster[type]['count']
#     if $cluster[type].key?('reserve_count')
#       reserve_count = $cluster[type]['reserve_count']
#     else
#       reserve_count = 0
#     end
#     (1..base_count+reserve_count).each do |i|
#       config.vm.define (vm_name = "%s%02d" % [type[0,1],i]),autostart:(i <= base_count) do |m|
#         m.vm.hostname = vm_name
#         m.vm.post_up_message = "Started %s %d" % [type, i]
#         m.vm.provider :virtualbox do |v|
# # we don't seem to be able to assign a new name here. It causes vagrant/virtualbox to rename the VM
# # after one with a random name was already created. This fails when moving the corrsponding directory
# # (I presume vagrant executes as a different user, but haven't checked). The only drawback of this
# # is that the second disk we attach is not in the place we'd like
# #          v.name = "%s_%s_%d" % [$cluster_name, type, i];
#           v.memory = $cluster[type]['memory']
#           v.cpus = 1 # get it from cluster def
#           v.gui = false
#           line = `VBoxManage list systemproperties | grep "Default machine folder"`
#           vb_machine_folder = line.split(':')[1].strip()
#           second_disk = File.join(vb_machine_folder, vm_name, 'cluster_disk.vdi')
#           unless File.exist?(second_disk)
#             v.customize ['createhd', '--filename', second_disk, '--size', 20 * 1024] # 20Gb hard disk
#           end
#           v.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', second_disk]
#         end
#         ip = machineIP(type, i)
#         #                 machine cert_base_name cn ip_addr
#         if type == "master"
#           provisionMachineSSL(m, "apiserver", "kube-apiserver-#{ip}", $cluster[type]['ips'])
#         end
#         if type == "worker"
#           provisionMachineSSL(m, "worker", "kube-worker-#{ip}", [ip])
#         end
#         env_file = Tempfile.new('env_file')
# #        env_file.write("ETCD_ENDPOINTS=#{etcd_endpoints}\n")
#         env_file.write("CONTROLLER_ENDPOINT=https://#{ip}\n") #TODO(aaron): LB or DNS across control nodes
#         env_file.close
#         m.vm.provision :file, :source => env_file, :destination => "/tmp/coreos-kube-options.env"
#         m.vm.provision :shell, :inline => "mkdir -p /run/coreos-kubernetes && mv /tmp/coreos-kube-options.env /run/coreos-kubernetes/options.env", :privileged => true

#         if $cluster[type].key?('provision')
#     #   puts "PROVISION FOR ", type, " IS ", $cluster[type]['provision']
#           m.vm.provision :file, :source => $cluster[type]['provision'], :destination => "/tmp/vagrantfile-user-data"
#           m.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
#         end
#         m.vm.network :private_network, ip: ip
#       end
#     end
#   end


#   if File.exist?(CLOUD_CONFIG_PATH)
#     config.vm.provision :file, :source => "#{CLOUD_CONFIG_PATH}", :destination => "/tmp/vagrantfile-user-data"
#     config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
#   end

# end
  

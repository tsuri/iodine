require 'enumerate'

def downloadKubernetesBinaries(binaries_dir, version_wanted, files)
  version_file="#{binaries_dir}/version"
  version_available="none"
  if File.exist?(version_file)
    version_available = File.read(version_file).chomp
  end

  version_mismatch = 0
  if version_available != version_wanted
    puts "Version mismatch [available: #{version_available}, desired: #{version_wanted}]"
    version_mismatch = 1
  end
  
  files.each do |file|
    filename="#{binaries_dir}/#{file}"
    if !File.exist?(filename) || version_mismatch == 1
      urlDomain = "storage.googleapis.com"
      urlResource = "/kubernetes-release/release/v#{version_wanted}/bin/linux/amd64/#{file}"
      puts "Trying to download #{urlDomain}#{urlResource}..."
      Net::HTTP.start(urlDomain) do |http|
        resp = http.get(urlResource)
        open(filename, "wb") do |f|
          f.write(resp.body)
        end
      end
      puts "Download complete."
    end
  end

   open("#{version_file}", "wb") do |f|
     f.write("#{version_wanted}")
   end
end

def generateSSLCertificates()
  # Generate root CA
  system("mkdir -p ssl && ./scripts/init-ssl-ca ssl") or abort ("failed generating SSL artifacts")
  # Generate admin key/cert
  system("./scripts/init-ssl ssl admin kube-admin") or abort("failed generating admin SSL artifacts")
end
  
def validateClusterConfig(config)
  if config['servers']['worker']['memory'] < 1024
    puts "WARNING: workers should have at least 1GB of memory"
  end

  if config['servers']['etcd']['count'] % 2 == 0 || config['servers']['etcd']['count'] > 5
    puts "WARNING etcd cluster should have 1,3 or 5 members"
  end
  
  # TODO(mav) only workers can have a 'reserve_count', check
end

def assignIPs(cluster)
  (cluster['servers'].keys).each do |type|
    ips = [*1..cluster['servers'][type]['count']].map{ |i| machineIP(type, i) }
    cluster['servers'][type]['ips'] = ips
    if type == 'etcd' or type == 'coreos'
      # TODO(mav) we need 4xxx for coreos and 6xxx for kubernetes
      cluster['servers'][type]['endpoints'] = ips.map{ |ip| "http://#{ip}:2379" }.join(",")
      cluster['servers'][type]['initial-cluster'] = ips.map.with_index{ |ip, i| "#{machineName(type, i+1)}=http://#{ip}:2380"}.join(",")
    end
  end

  return cluster
end
  
def getClusterConfig(filenames)
  cluster = Hash.new
  filenames.each do |filename|
    cluster.deep_merge!(YAML.load(IO.readlines(filename)[1..-1].join))
  end
  validateClusterConfig(cluster)
  cluster = assignIPs(cluster)
  return cluster
end

def configureUserData(instances)
  # Used to fetch a new discovery token for a cluster of size $num_instances
  # (should limit to 3-5, everybody ese becomes an etcd proxy
  new_discovery_url="https://discovery.etcd.io/new?size=#{instances}"

  # Automatically replace the discovery token on 'vagrant up'. But not
  # when we do a vagrant up MACHINE as we want new machines to join the cluster
  if File.exists?('user-data') && ARGV[0].eql?('up') && ARGV.length < 2
    require 'open-uri'
    require 'yaml'

    token = open(new_discovery_url).read

    data = YAML.load(IO.readlines('user-data')[1..-1].join)

    if data.key? 'coreos' and data['coreos'].key? 'etcd2'
      data['coreos']['etcd2']['discovery'] = token
    end

    # Fix for YAML.load() converting reboot-strategy from 'off' to `false`
    if data.key? 'coreos' and data['coreos'].key? 'update' and data['coreos']['update'].key? 'reboot-strategy'
      if data['coreos']['update']['reboot-strategy'] == false
        data['coreos']['update']['reboot-strategy'] = 'off'
      end
    end

    yaml = YAML.dump(data)
    File.open('user-data', 'w') { |file| file.write("#cloud-config\n\n#{yaml}") }
  end
end

def machineIP(type, n)
  if type == "coreos"
    base = 20
  elsif type == "etcd"
    base = 50
  elsif type == "master"
    base = 100
  elsif type == "worker"
    base = 200
  end
  return "172.28.8.#{base+n}"
end

def machineName(type, n)
  return "%s%02d" % [type[0,1],n]
end

def provisionMachineSSL(machine,certBaseName,cn,ipAddrs)
  tarFile = "ssl/#{cn}.tar"
  ipString = ipAddrs.map.with_index { |ip, i| "IP.#{i+1}=#{ip}"}.join(",")
  system("./scripts/init-ssl ssl #{certBaseName} #{cn} #{ipString}") or abort("failed generating #{cn} SSL artifacts")
  machine.vm.provision :file, :source => tarFile, :destination => "/tmp/ssl.tar"
  machine.vm.provision :shell, :inline => "mkdir -p /etc/kubernetes/ssl && tar -C /etc/kubernetes/ssl -xf /tmp/ssl.tar", :privileged => true
end

              # sed -i -e "s|__HOSTNAME__|#{member}|" \
              #        -e "s|__INITIAL_COREOS_ETCD_CLUSTER__|#{INITIAL_COREOS_ETCD_CLUSTER}|" \
              #        -e "s|__INITIAL_KUBERNETES_ETCD_CLUSTER__|#{INITIAL_KUBERNETES_ETCD_CLUSTER}|" \
              #        -e "s|__COREOS_ETCD_SERVERS__|#{COREOS_ETCD_SERVERS}|" \

def make_binding(hash)
  __b = binding
  hash.each{|k, v|
    __b.local_variable_set(k, v)
  }
  __b
end

def instantiate(template, dest, vars)
  template = ERB.new File.read(template)
  File.write(dest, template.result(make_binding(vars)))
end

# def replace(hash)
#   hash.inject({}) do |h,(k,v)|
#     if v.kind_of? String
#       h[k] = v.upcase
#     elsif v.kind_of? Fixnum
#       h[k] = v
#     else
#       h[k] = replace(v)
#     end
#     h
#   end      
# end

def provisionServers(binaries_dir, config, type, template)
  Dir.mkdir("OUT") unless File.directory?("OUT")

  base_count = template['count']
  if template.key?('reserve')
    reserve_count = template['reserve']
  else
    reserve_count = 0
  end
  puts "PROVISIONING SERVERS OF TYPE #{type} (#{base_count} + #{reserve_count} instances)"

  
  (1..base_count+reserve_count).each do |i|
    ip = machineIP(type, i)
    config.vm.define (vm_name = "%s%02d" % [type[0,1],i]),autostart:(i <= base_count) do |m|
      puts "\tdefining machine #{vm_name}, #{ip}"
      system "ssh-keygen -f /home/mav/.ssh/known_hosts -R #{ip} > /dev/null 2>&1"
      system "ssh-keygen -f /home/mav/.ssh/known_hosts -R #{vm_name} > /dev/null 2>&1"

      m.vm.provider :virtualbox do |vb|
        vb.gui = false
        vb.linked_clone = true
        vb.memory = template['memory']
        vb.cpus = template['cpu']

        if ARGV[0] == "up" && template.key?('disks')
          template['disks'].each_with_index do |disk, i|
            disk_size = disk[0]
            disk_type = disk[1]
            second_disk = File.join('/cluster_data/disks', vm_name, "cluster_disk_#{i}.vdi")
#            second_disk = File.join(vb_machine_folder, vm_name, "cluster_disk_#{i}.vdi")
            unless File.exist?(second_disk)
              puts ">>>> createhd #{second_disk}"
              vb.customize ['createhd', '--filename', second_disk, '--size', 20 * 1024] # 20Gb hard disk
            end
            puts ">>>> storageattach #{second_disk}"
            vb.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', i, '--type', 'hdd', '--medium', second_disk]
          end
        end
        
      end
      m.vm.hostname = vm_name
      m.vm.network :private_network, ip: ip
      vars = {
        :hostname => vm_name,
        :initial_coreos_etcd_cluster => $cluster['servers']['coreos']['initial-cluster'],
        :coreos_etcd_servers => $cluster['servers']['coreos']['endpoints'],
      }
#      pp vars
      instantiate(template['provision'], "OUT/cloudinit_#{vm_name}", vars)
      m.vm.provision :file, :source => "OUT/cloudinit_#{vm_name}", :destination => "/tmp/vagrantfile-user-data"
      m.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true

      required_binaries = []
      if type == 'master'
        required_binaries = REQUIRED_BINARIES_FOR_MASTER
      end
      if type == 'worker'
        required_binaries = REQUIRED_BINARIES_FOR_NODES
      end

      required_binaries.each do |filename|
        file="#{binaries_dir}/#{filename}"
        puts ">>> #{type}: #{filename} (form #{file})\n"
        m.vm.provision :file, :source => "#{file}", :destination => "/tmp/#{filename}"
        m.vm.provision :shell, :privileged => true, inline: <<-EOF
          echo "Copying host:#{file} to vm:/opt/bin/#{filename}.."
          mkdir -p /opt/bin
          cp "/tmp/#{filename}" "/opt/bin/#{filename}"
          chmod +x "/opt/bin/#{filename}"
EOF
      end

    end                         # machine def
  end                           # iteration of instances
end

# def provisionServers(binaries_dir, config, type, template)
#   puts "PROVISIONING SERVERS OF TYPE #{type}"
#   base_count = template['count']
#   if template.key?('reserve')
#     reserve_count = template['reserve']
#   else
#     reserve_count = 0
#   end

# #  data = YAML.load(IO.readlines(template['provision'])[1..-1].join)
# #  data = replace(data)
# #  yaml = YAML.dump(data)
# #  puts yaml

#   Dir.mkdir("OUT") unless File.directory?("OUT")
                                    
#   (1..base_count+reserve_count).each do |i|
#     ip = machineIP(type, i)
#     config.vm.define (vm_name = "%s%02d" % [type[0,1],i]),autostart:(i <= base_count) do |m|
#       m.vm.hostname = vm_name
#       m.vm.network :private_network, ip: ip

#       puts "Doing machine #{vm_name}"
#       vars = {
#         :hostname => vm_name,
#         :initial_coreos_etcd_cluster => $cluster['servers']['coreos']['initial-cluster'],
#         :coreos_etcd_servers => $cluster['servers']['coreos']['endpoints'],
#       }
# #      pp vars
#       instantiate(template['provision'], "OUT/cloudinit_#{vm_name}", vars)

#       m.vm.post_up_message = "Started %s %d" % [type, i]

# #       m.vm.provider :virtualbox do |v|
# #         puts "+++"
# #         if template.key?('disks')
# #           template['disks'].each_with_index do |disk, i|
# #             disk_size = disk[0]
# #             disk_type = disk[1]
# # #            vm_folders = `VBoxManage list systemproperties | grep "Default machine folder"`
# # #            vb_machine_folder = vm_folders.split(':')[1].strip()
# #             second_disk = File.join('/cluster_data/disks', vm_name, "cluster_disk_#{i}.vdi")
# # #            second_disk = File.join(vb_machine_folder, vm_name, "cluster_disk_#{i}.vdi")
# #             unless File.exist?(second_disk)
# #               puts ">>>> createhd #{second_disk}"
# #               v.customize ['createhd', '--filename', second_disk, '--size', 20 * 1024] # 20Gb hard disk
# #             end
# #             puts ">>>> storageattach #{second_disk}"
# #             v.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', i, '--type', 'hdd', '--medium', second_disk]
# #           end
# #         end
# #       end

#       # apiserver and worker can be asbtracted, IPs I don't know
#       if template.key?('cert')
#         if template['cert_type'] == 'self'
#           ips = [ip]
#         else
#           ips = template['ips']
#         end
#         provisionMachineSSL(m, template['cert'], "kube-#{template['cert']}-#{ip}", ips)
#       end

#       m.vm.synced_folder ".", "/vagrant", create: true, mount_options: ['nolock', 'vers=3', 'udp', 'noatime']

#       # required_binaries = []
#       # if type == 'master'
#       #   required_binaries = REQUIRED_BINARIES_FOR_MASTER
#       # end
#       # if type == 'worker'
#       #   required_binaries = REQUIRED_BINARIES_FOR_NODES
#       # end

#       # required_binaries.each do |filename|
#       #   file="#{binaries_dir}/#{filename}"
#       #   puts ">>> #{type}: #{filename} (form #{file})\n"
#       #   m.vm.provision :file, :source => "#{file}", :destination => "/tmp/#{filename}"
#       #   m.vm.provision :shell, :privileged => true, inline: <<-EOF
#       #     echo "Copying host:#{file} to vm:/opt/bin/#{filename}.."
#       #     mkdir -p /opt/bin
#       #     cp "/tmp/#{filename}" "/opt/bin/#{filename}"
#       #     chmod +x "/opt/bin/#{filename}"
#       #   EOF

#       # end

#       m.vm.provision :file, :source => "OUT/cloudinit_#{vm_name}", :destination => "/tmp/vagrantfile-user-data"
#       m.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true

#       # if template.key?('disks')
#       #   template['disks'].each_with_index do |disk, i|
#       #     disk_size = disk[0]
#       #     disk_type = disk[1]
#       #     disk_storage = File.join('/cluster_data/disks', vm_name, "cluster_disk_#{i}.vdi")
#       #     puts ">>> Adding #{disk_type} disk of size #{disk_size}Gb (on disk at #{disk_storage})"
#       #     unless File.exist?(disk_storage)
#       #       puts ">>>      creating disk"
#       #       config.vm.provider :virtualbox do |vb|
#       #         pp vb.name
#       #         puts ">>>      customize #{vb.name}"
#       #       end
#       #     end
#       #       # v.customize ['createhd', '--filename', second_disk, '--size', 20 * 1024] # 20Gb hard disk          end
#       #   end
#       # end
      
#     end
#   end
#   m.vm.provider :virtualbox do |v|
#     #        puts ">>> #{v.name}"
#     #       v.name = vm_name
#   end
# end

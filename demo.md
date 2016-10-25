- bunch of coreos VMs

- cluster of coreos VMs

- differentiated machines, separate etcd cluster 

- flannel

	- show the flannel0 interface and routing
	- show etcdctl ls
	- on w01, run a light container w/ bash
	  docker run -ti debian absh
	- login and get IP
	  docker inspect CONTAINER-ID
	- on w02, ping IP
	- kill bash
	- keep pinging and yo'll get error
	- restart bash, most likely ping restart succesfully
	
- apiserver

	- on m01, curl --stderr /dev/null http://localhost:8080/api/v1/nodes/
	  no nodes.
	  
	- on w03, sudo /opt/bin/kubelet --api-servers=172.28.8.101:8080
	- on m1, same command show now the new node.
	
	This is without any authentication.
	
- kubelet

- external access

- scheduler/controller

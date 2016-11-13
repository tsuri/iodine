
# kubectl get cs
# NAME                 STATUS    MESSAGE              ERROR
# controller-manager   Healthy   ok                   
# scheduler            Healthy   ok                   
# etcd-0               Healthy   {"health": "true"}   


# curl  -L http://172.28.8.15:2379/v2/keys/registry
# {"action":"get","node":{"key":"/registry","dir":true,"nodes":[{"key":"/registry/services","dir":true,"modifiedIndex":11,"createdIndex":11},{"key":"/registry/events","dir":true,"modifiedIndex":15,"createdIndex":15},{"key":"/registry/minions","dir":true,"modifiedIndex":31,"createdIndex":31},{"key":"/registry/deployments","dir":true,"modifiedIndex":926,"createdIndex":926},{"key":"/registry/pods","dir":true,"modifiedIndex":928,"createdIndex":928},{"key":"/registry/ranges","dir":true,"modifiedIndex":8,"createdIndex":8},{"key":"/registry/namespaces","dir":true,"modifiedIndex":10,"createdIndex":10},{"key":"/registry/serviceaccounts","dir":true,"modifiedIndex":20,"createdIndex":20},{"key":"/registry/replicasets","dir":true,"modifiedIndex":927,"createdIndex":927}],"modifiedIndex":8,"createdIndex":8}}

#!/bin/bash

kubectl config set-cluster infra-cluster --server=http://172.28.8.20:8080

kubectl config set-context infra-prod --cluster=infra-cluster --user=default-admin

kubectl config use-context infra-prod

#!/bin/bash

echo "Running VMs"
vboxmanage list runningvms

echo
echo "VM  pid"
egrep "Process ID" ~/VirtualBox\ VMs/*new_*/Logs/VBox.log| cut -d_ -f2,4|sed -e 's,^\([^_]*\).*Process ID: \([0-9]*\)$,\1 \2,g'

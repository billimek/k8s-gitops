#!/bin/sh

TEMPLATE=9002

#####################
## MASTER NODES
#####################
echo "#####################"
echo "## MASTER NODES"
echo "#####################"
qm clone "$TEMPLATE" 200 --name k8s-master-a
qm set 200 --sshkey ~/.ssh/id_k8s_nodes.pub
qm set 200 --ipconfig0 ip=10.2.0.10/24,gw=10.2.0.1
qm set 200 --ipconfig1 ip=10.0.10.50/24

qm clone "$TEMPLATE" 201 --name k8s-master-b
qm set 201 --sshkey ~/.ssh/id_k8s_nodes.pub
qm set 201 --ipconfig0 ip=10.2.0.11/24,gw=10.2.0.1
qm set 201 --ipconfig1 ip=10.0.10.51/24
qm migrate 201 proxmox-b

qm clone "$TEMPLATE" 202 --name k8s-master-c
qm set 202 --sshkey ~/.ssh/id_k8s_nodes.pub
qm set 202 --ipconfig0 ip=10.2.0.12/24,gw=10.2.0.1
qm set 202 --ipconfig1 ip=10.0.10.52/24
qm migrate 202 proxmox-c

qm start 200
ssh proxmox-b 'qm start 201'
ssh proxmox-c 'qm start 202'
#####################
## WORKER NODES
#####################
echo "#####################"
echo "## WORKER NODES"
echo "#####################"
qm clone "$TEMPLATE" 203 --name k8s-1
qm set 203 --sshkey ~/.ssh/id_k8s_nodes.pub
qm set 203 --ipconfig0 ip=10.2.0.13/24,gw=10.2.0.1
qm set 203 --ipconfig1 ip=10.0.10.53/24
qm set 203 --scsi1 /dev/disk/by-id/ata-Samsung_SSD_860_EVO_500GB_S3Z1NW0KA01733D,discard=on,backup=0,ssd=1,replicate=0,serial=S3Z1NW0KA01733D
qm set 203 --memory 8192

qm clone "$TEMPLATE" 204 --name k8s-2
qm set 204 --sshkey ~/.ssh/id_k8s_nodes.pub
qm set 204 --ipconfig0 ip=10.2.0.14/24,gw=10.2.0.1
qm set 204 --ipconfig1 ip=10.0.10.54/24
qm set 204 --memory 8192
qm set 204 -hostpci0 00:02.0,mdev=i915-GVTg_V5_8
qm migrate 204 proxmox-b

qm clone "$TEMPLATE" 205 --name k8s-3
qm set 205 --sshkey ~/.ssh/id_k8s_nodes.pub
qm set 205 --ipconfig0 ip=10.2.0.15/24,gw=10.2.0.1
qm set 205 --ipconfig1 ip=10.0.10.55/24
qm set 205 --memory 8192
qm migrate 205 proxmox-c

qm start 203
ssh proxmox-b 'qm set 204 --scsi1 /dev/disk/by-id/ata-Samsung_SSD_860_EVO_500GB_S3Z1NW0KA01748E,discard=on,backup=0,ssd=1,replicate=0,serial=S3Z1NW0KA01748E && qm start 204'
ssh proxmox-c 'qm set 205 --scsi1 /dev/disk/by-id/ata-Samsung_SSD_860_EVO_500GB_S3Z1NB0K624788N,discard=on,backup=0,ssd=1,replicate=0,serial=S3Z1NB0K624788N && qm start 205'
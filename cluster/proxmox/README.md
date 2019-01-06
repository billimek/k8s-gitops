# Kubernetes nodes in proxmox

On `proxmox` host OS:

## Base template

Create the base template:

```shell
qm create 9001 --memory 4096 --cores 4 --net0 virtio,bridge=vmbr0,tag=20 --net1 virtio,bridge=vmbr1
qm importdisk 9001 /tank/data/ubuntu-18.10-server-cloudimg-amd64.img proxmox
qm set 9001 --scsihw virtio-scsi-pci --scsi0 proxmox:9001/vm-9001-disk-0.raw,ssd=1,discard=on
qm resize 9001 scsi0 32G
qm set 9001 --ide2 proxmox:cloudinit
qm set 9001 --boot c --bootdisk scsi0
qm set 9001 --serial0 socket --vga serial0
qm set 9001 --ostype l26
qm set 9001 --agent enabled=1,fstrim_cloned_disks=1
qm template 9001
```

## RKE specific template

Based on the above base, create the rke template:

```shell
qm clone 9001 9002 --name rke-template
qm set 9002 --sshkey ~/.ssh/id_rsa.pub
qm set 9002 --ipconfig0 ip=10.0.7.50/24,gw=10.0.7.1
qm set 9002 --ipconfig1 ip=10.0.10.50/24
```

Enhance the rke template with necessary tools and tweaks:

```shell
qm start 9002
ssh ubuntu@10.0.7.50

sudo apt-get install htop glances iotop zsh jq ceph-common gdisk iperf qemu-guest-agent nfs-common  docker.io
sudo usermod -aG docker ubuntu
sudo rm /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
exit

qm template 9002
```

## Create the nodes

Execute [create_nodes.sh](create_nodes.sh) on `proxmox` to create the 3 master and 3 worker nodes

## Cleanup

Execute [remove_nodes.sh](remove_nodes.sh) on `proxmox` to remove all the created nodes

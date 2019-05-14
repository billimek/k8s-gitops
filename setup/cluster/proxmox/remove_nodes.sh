#!/bin/sh

qm stop 200 && qm destroy 200
ssh proxmox-b 'qm stop 201 && qm destroy 201'
ssh proxmox-c 'qm stop 202 && qm destroy 202'
qm stop 203 && qm destroy 203 && sgdisk -z /dev/disk/by-id/ata-Samsung_SSD_860_EVO_500GB_S3Z1NW0KA01733D
ssh proxmox-b 'qm stop 204 && qm destroy 204 && sgdisk -z /dev/disk/by-id/ata-Samsung_SSD_860_EVO_500GB_S3Z1NW0KA01748E'
ssh proxmox-c 'qm stop 205 && qm destroy 205 && sgdisk -z /dev/disk/by-id/ata-Samsung_SSD_860_EVO_500GB_S3Z1NB0K624788N'
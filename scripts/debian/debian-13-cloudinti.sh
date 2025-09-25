#! /bin/bash

VMID=8000
STORAGE=ssd1

apt update -y && apt install libguestfs-tools -y
cd /var/lib/vz/template/iso
set -x
rm -f debian-13-generic-amd64.qcow2
wget -q https://cloud.debian.org/images/cloud/bookworm/latest/debian-13-generic-amd64.qcow2
virt-customize -a /var/lib/vz/template/iso/debian-13-generic-amd64.qcow2 --install qemu-guest-agent
virt-customize -a /var/lib/vz/template/iso/debian-13-generic-amd64.qcow2 --root-password password:Relation123!
virt-customize -a /var/lib/vz/template/iso/debian-13-generic-amd64.qcow2 --run-command "echo -n > /etc/machine-id"
qemu-img resize debian-13-generic-amd64.qcow2 8G
 qm destroy $VMID
 qm create $VMID --name "debian-12-template" --ostype l26 \
    --memory 2048 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu x86-64-v2-AES --cores 2 --numa 1 \
    --net0 virtio,bridge=vmbr0,mtu=1
 qm importdisk $VMID debian-13-generic-amd64.qcow2 $STORAGE
 qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
 qm set $VMID --boot order=virtio0
 qm set $VMID --scsi1 $STORAGE:cloudinit

#Just for Custom Cloud Config
#cat << EOF |  tee /var/lib/vz/snippets/debian-13.yaml
##cloud-config
#runcmd:
#    - apt-get update
#    - apt-get install -y qemu-guest-agent
#    - reboot
## Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
#EOF
##Custom Cloud Config switch
# qm set $VMID --cicustom "vendor=local:snippets/debian-13.yaml"
 qm set $VMID --tags debian-template,debian-13,cloudinit
 qm set $VMID --ciuser $USER
 qm set $VMID --sshkeys ~/.ssh/authorized_keys
 qm set $VMID --ipconfig0 ip=dhcp
 qm template $VMID

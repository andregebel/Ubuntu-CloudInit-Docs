#! /bin/bash

VMID=8199
STORAGE=ssd1

apt update -y && apt install libguestfs-tools -y
cd /var/lib/vz/template/iso
set -x
rm -f focal-server-cloudimg-amd64.img
wget -q https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
virt-customize -a /var/lib/vz/template/iso/focal-server-cloudimg-amd64.img --install qemu-guest-agent
virt-customize -a /var/lib/vz/template/iso/focal-server-cloudimg-amd64.img --root-password password:Relation123!
virt-customize -a /var/lib/vz/template/iso/focal-server-cloudimg-amd64.img --run-command "echo -n > /etc/machine-id"
qemu-img resize focal-server-cloudimg-amd64.img 8G
 qm destroy $VMID
 qm create $VMID --name "ubuntu-20.04.LTS-template" --ostype l26 \
    --memory 2048 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 2 \
    --net0 virtio,bridge=vmbr0
 qm importdisk $VMID focal-server-cloudimg-amd64.img $STORAGE
 qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
 qm set $VMID --boot order=virtio0
 qm set $VMID --scsi1 $STORAGE:cloudinit

#cat << EOF |  tee /var/lib/vz/snippets/ubuntu.yaml
##cloud-config
#runcmd:
#    - apt-get update
#    - apt-get install -y qemu-guest-agent
#    - systemctl enable ssh
#    - reboot
## Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
#EOF
#
# qm set $VMID --cicustom "vendor=local:snippets/ubuntu.yaml"
 qm set $VMID --tags ubuntu-template,focal,cloudinit,20.04.LTS
 qm set $VMID --ciuser $USER
 qm set $VMID --sshkeys ~/.ssh/authorized_keys
 qm set $VMID --ipconfig0 ip=dhcp
 qm template $VMID

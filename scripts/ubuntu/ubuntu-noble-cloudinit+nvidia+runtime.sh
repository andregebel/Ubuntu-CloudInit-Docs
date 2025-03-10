#! /bin/bash

VMID=8202
STORAGE=ssd1

apt update -y && apt install libguestfs-tools -y
cd /var/lib/vz/template/iso
set -x
rm -f noble-server-cloudimg-amd64+nivida.img
wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img -O noble-server-cloudimg-amd64+nivida.img
virt-customize -a /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img --install qemu-guest-agent
virt-customize -a /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img --root-password password:Relation123!
virt-customize -a /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img --run-command "echo -n > /etc/machine-id"
qemu-img resize noble-server-cloudimg-amd64.img 8G
 qm destroy $VMID
 qm create $VMID --name "ubuntu-24.04.LTS-template-nvidia-runtime" --ostype l26 \
    --memory 2048 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 2 \
    --net0 virtio,bridge=vmbr0
 qm importdisk $VMID noble-server-cloudimg-amd64.img $STORAGE
 qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
 qm set $VMID --boot order=virtio0
 qm set $VMID --scsi1 $STORAGE:cloudinit

cat << EOF |  tee /var/lib/vz/snippets/ubuntu-noble-runtime.yaml
#cloud-config
runcmd:
    - curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    - curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    - apt-get update
    - apt-get install -y qemu-guest-agent nvidia-dkms-550-server nvidia-utils-550-server nvidia-container-runtime
    - systemctl enable ssh
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF
#Custom Cloud Config switch
  qm set $VMID --cicustom "vendor=local:snippets/ubuntu-noble-runtime.yaml"
 qm set $VMID --cicustom "vendor=local:snippets/ubuntu-noble-runtime.yaml"
 qm set $VMID --tags ubuntu-template,noble,cloudinit,nvidia,24.04.LTS
 qm set $VMID --ciuser $USER
 qm set $VMID --sshkeys ~/.ssh/authorized_keys
 qm set $VMID --ipconfig0 ip=dhcp
 qm template $VMID

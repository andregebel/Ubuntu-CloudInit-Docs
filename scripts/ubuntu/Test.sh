# Load Image
apt update -y && apt install libguestfs-tools -y
cd /var/lib/vz/template/iso

wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img &&
virt-customize -a /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img --install qemu-guest-agent &&
virt-customize -a /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img --root-password password:Relation123!&&
virt-customize -a /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img --run-command "echo -n > /etc/machine-id"

#Needs to be worked on

### Cloudinit Template VM erstellen (Ubuntu 24.04)
### https://www.thomas-krenn.com/de/wiki/Cloud_Init_Templates_in_Proxmox_VE_-_Quickstart

qm create 9501 --name "ubuntu-2404-ci" --memory 2048 --cores 1 --net0 virtio,bridge=vmbr0 &&
qm importdisk 9501 /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img vm_nvme &&
qm set 9501 --scsihw virtio-scsi-single --scsi0 vm_nvme:vm-9501-disk-0,cache=writeback,discard=on,ssd=1 &&
qm set 9501 --scsi1 vm_nvme:60,cache=writeback,discard=on,ssd=1 &&
qm set 9501 --boot c --bootdisk scsi0 &&
qm set 9501 --scsi2 vm_nvme:cloudinit &&
qm set 9501 --agent enabled=1 &&
qm resize 9501 scsi0 32G &&
qm set 9501 --serial0 socket &&
qm set 9501 --vga serial0 &&
qm set 9501 --cpu cputype=host &&
qm set 9501 --ostype l26 &&
qm set 9501 --balloon 4096 &&
qm set 9501 --ciupgrade 1 &&
qm set 9501 --ciuser ansible &&
qm set 9501 --ipconfig0 ip=dhcp &&
qm set 9501 --nameserver 192.168.110.61 &&
qm set 9501 --searchdomain pmx.local &&
qm set 9501 --sshkeys /mnt/pve/cephfs/configs/authorized_keys &&
qm template 9501
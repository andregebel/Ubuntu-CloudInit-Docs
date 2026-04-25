# Making Ubuntu VM Templates for Proxmox and CloudInit

This is a short guide for setting up Ubuntu VM templates in Proxmox using CloudInit in a scriptable manner.

Supported releases:
- **Ubuntu 24.04 LTS (Noble Numbat)**
- **Ubuntu 26.04 LTS (Resolute Rampager)**

For this guide I have made a few assumptions:

* You want your VMs to boot via UEFI as opposed to BIOS
* Your Proxmox node's main storage is called `local-zfs`
* You have SSH keys stored in ~/.ssh/authorized_keys of your regular user's home folder

## Quick start

### Ubuntu 24.04 (Noble)

```bash
export VMID=8200 STORAGE=local-zfs
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/Ubuntu-CloudInit-Docs/main/samples/ubuntu/ubuntu-noble-cloudinit.sh | bash
```

### Ubuntu 26.04 (Resolute)

```bash
export VMID=8200 STORAGE=local-zfs
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/Ubuntu-CloudInit-Docs/main/samples/ubuntu/ubuntu-resolute-cloudinit.sh | bash
```

Other scripts are available in the [samples](./samples) directory, and can be used similarly to the above.

## The basics

The first step is to enable support for snippets in the local dataset. Log into the Proxmox web UI and click Datacenter on the left, then Storage. Click local then Edit and a small window will pop up. In the Content drop down click on snippets, then OK.

Now log into Proxmox via SSH so that we can download a cloud image and resize it.

**Ubuntu 24.04 (Noble):**

    wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
    qemu-img resize noble-server-cloudimg-amd64.img 32G

**Ubuntu 26.04 (Resolute):**

    wget -q https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img
    qemu-img resize resolute-server-cloudimg-amd64.img 32G

Notice that even though I'm resizing this image to be 32 gigabytes the file won't actually be 32 gigabytes in size, this is because the image is what's called a sparse file. The image starts out at around ~2GB but unless we resize the image now any cloned VMs won't have any storage. Feel free to change the 32G to 20, 80 or whatever you like.

## Creating the VM

The next step is to create a basic VM that we'll build upon (substitute the image name for whichever release you're using):

    sudo qm create 8001 --name "ubuntu-2604-cloudinit-template" --ostype l26 \
        --memory 1024 \
        --agent 1 \
        --bios ovmf --machine q35 --efidisk0 local-zfs:0,pre-enrolled-keys=0 \
        --cpu host --sockets 1 --cores 1 \
        --vga serial0 --serial0 socket  \
        --net0 virtio,bridge=vmbr0

Feel free to change the 8001 to whatever you like, so long as you replace the 8001 in subsequent commands to whatever you chose. The memory chosen doesn't really matter because this particular VM won't start, make sure to adjust the amount of RAM for cloned VMs. `--agent 1` enables the Qemu Guest Agent which is useful for all sorts of things like seeing the IP addresses of any interfaces. We'll set the CPU type to host (you almost always want this) with one socket and one core (remember to change the number of cores in cloned VMs). Next is the GPU, you can choose virtio instead of serial0 if you like but there's no need; serial gpu type does let you copy and paste which can be useful. Finally is the NIC, if you have a special bridge interface you want to choose change `vmbr0` to whatever you like. If you want to use a VLAN tag add `,tag=##` immediately after the bridge name (no spaces).

## Configuring hardware

    sudo qm importdisk 8001 resolute-server-cloudimg-amd64.img local-zfs
    sudo qm set 8001 --scsihw virtio-scsi-pci --virtio0 local-zfs:vm-8001-disk-1,discard=on
    sudo qm set 8001 --boot order=virtio0
    sudo qm set 8001 --scsi1 local-zfs:cloudinit

The first command imports the image we downloaded earlier; if your disk storage is not local-zfs (for example local-lvm) then replace it with whatever you wish. The next command attaches the disk to the VM. If your disk storage is not on SSDs (which it should be) omit `,discard=on`. The third command sets the boot order. The fourth adds the cloudinit pseudo-cdrom drive.

## Creating the vendor.yaml file for cloudinit

    mkdir /var/lib/vz/snippets
    cat << EOF | sudo tee /var/lib/vz/snippets/vendor.yaml
    #cloud-config
    runcmd:
        - apt-get update
        - apt-get install -y qemu-guest-agent
        - systemctl enable ssh
        - reboot
    # Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
    EOF

This file performs two purposes: the first rather obvious (installing qemu-guest-agent), the second not so much. For some reason CloudInit starts *after* networking and thus you can't SSH or even ping the VM by the name you give it. This package is only run once so after this reboot you'll be able to use the VM.

## Set timezone and locale

Setting the timezone and locale is important for accurate timekeeping and localization.

    echo "timezone: "$(cat /etc/timezone) | sudo tee -a /var/lib/vz/snippets/vendor.yaml
    echo "locale: "$LANG | sudo tee -a /var/lib/vz/snippets/vendor.yaml

Make sure your system's timezone and locale is correct first!

## Configuring CloudInit

    sudo qm set 8001 --cicustom "vendor=local:snippets/vendor.yaml"
    sudo qm set 8001 --tags ubuntu-template,resolute,cloudinit
    sudo qm set 8001 --ciuser untouchedwagons
    sudo qm set 8001 --cipassword $(openssl passwd -6 $CLEARTEXT_PASSWORD)
    sudo qm set 8001 --sshkeys ~/.ssh/authorized_keys
    sudo qm set 8001 --ipconfig0 ip=dhcp,ip6=dhcp

The first command tells CI to use the vendor file we specified earlier. The second can be skipped but adds decorative tags that show up in the Proxmox Web-UI. Cloned VMs inherit all these tags. The third specifies the user to create. The fourth sets the password. The fifth imports SSH public keys so you can SSH in. Finally the virtio NIC is set to DHCP, this is *supposed* to be the default but manual specifying is necessary.

## Finally: Converting to template

    sudo qm template 8001

That's it! Your template is now ready to use. Clone this template as you wish (remember to adjust cores and RAM as needed) and start up the clone. After first boot Cloud-Init will kick in, create your user, install qemu-guest-agent and reboot. Once the reboot is complete you can SSH and use the VM however you like!

## Sample scripts

In the [samples/ubuntu](./samples/ubuntu) folder are pre-made shell scripts to create Proxmox templates. At the top of each file are two environment variables (`VMID` and `STORAGE`) that can be adjusted to match your Proxmox setup.

| Script | Release | Default VMID | Notes |
|---|---|---|---|
| `ubuntu-noble-cloudinit.sh` | 24.04 Noble | 8200 | Base template |
| `ubuntu-noble-cloudinit+nvidia+runtime.sh` | 24.04 Noble | 8202 | + NVIDIA Container Toolkit (590 server) |
| `ubuntu-resolute-cloudinit.sh` | 26.04 Resolute | 8200 | Base template |
| `ubuntu-resolute-cloudinit+nvidia+runtime.sh` | 26.04 Resolute | 8202 | + NVIDIA Container Toolkit (590 server) |

> **Note on NVIDIA packages for 26.04:** The Resolute NVIDIA script uses `nvidia-dkms-590-server` and `nvidia-utils-590-server`, the same packages as Noble. Verify these are available in the Ubuntu 26.04 repos before running — check with `apt-cache search nvidia-dkms`.

See the [samples/debian](./samples/debian) directory for equivalent Debian templates.

## Thanks

Thanks to ilude for telling me what command is needed to set the CI password.

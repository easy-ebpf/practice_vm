packer {
    required_plugins {
        qemu = {
            version = "~> 1"
            source  = "github.com/hashicorp/qemu"
        }
        vagrant = {
            version = "~> 1"
            source = "github.com/hashicorp/vagrant"
        }
        virtualbox = {
            version = "~> 1"
            source  = "github.com/hashicorp/virtualbox"
        }
        proxmox = {
            version = "~> 1"
            source  = "github.com/hashicorp/proxmox"
        }
    }
}

source "qemu" "practice-vm" {
    iso_url = "https://releases.ubuntu.com/noble/ubuntu-24.04.2-live-server-amd64.iso"
    iso_checksum            = "file:https://releases.ubuntu.com/noble/SHA256SUMS"
    disk_size = "10000M"
    memory = "4096"
    cores = 2
    threads = 2
    output_directory = "build"
    format = "qcow2"
    vm_name = "practice-vm"
    net_device        = "virtio-net"
    disk_interface    = "virtio"
    headless = true
    vnc_bind_address = "0.0.0.0"
    vnc_use_password = true
    accelerator       = "kvm"
    boot_wait         = "10s"
    http_directory = "cloud-init"
    boot_steps = [
        ["<wait>e", "Wait for GRUB menu, and enter command edit mode."],
        ["<wait><down><down><down><end><left><left><left><left> autoinstall ip=dhcp cloud-config-url=http://{{.HTTPIP}}:{{.HTTPPort}}/autoinstall.yaml<wait><f10><wait>", "Enter the command to bootstrap the autoinstall.yaml"]
    ]
    communicator = "ssh"
    ssh_pty = true
    ssh_username = "ubuntu"
    ssh_password = "ubuntu"
    ssh_timeout = "10h"
    shutdown_command  = "echo 'ubuntu' | sudo -S shutdown -P now"
    shutdown_timeout = "10h"
}

source "virtualbox-iso" "practice-vm" {
    vm_name = "practice-vm"
    guest_os_type = "Ubuntu_64"
    hard_drive_discard = true
    format = "ova"
    iso_url = "https://releases.ubuntu.com/noble/ubuntu-24.04.2-live-server-amd64.iso"
    iso_checksum            = "file:https://releases.ubuntu.com/noble/SHA256SUMS"
    output_directory = "build"
    headless = true
    memory = 4096
    cpus = 4
    vboxmanage = [
        ["modifyvm", "{{.Name}}", "--vram", "128"]
    ]
    vrdp_bind_address = "0.0.0.0"
    communicator = "ssh"
    ssh_pty = true
    ssh_username = "ubuntu"
    ssh_password = "ubuntu"
    ssh_timeout = "10h"
    shutdown_command  = "echo 'ubuntu' | sudo -S shutdown -P now"
    shutdown_timeout = "10h"
    http_directory = "cloud-init"
    boot_command = [
        "<wait>e",
        "<wait><down><down><down><end><left><left><left><left> autoinstall ip=dhcp cloud-config-url=http://{{.HTTPIP}}:{{.HTTPPort}}/autoinstall.yaml<wait><f10><wait>"
    ]
}

source "proxmox-iso" "practice-vm" {
    boot_wait         = "10s"
    boot_command = [
        "<wait>e",
        "<wait><down><down><down><end><left><left><left><left> autoinstall ip=dhcp cloud-config-url=http://{{.HTTPIP}}:{{.HTTPPort}}/autoinstall.yaml<wait><f10><wait>"
    ]
    cores = 4
    memory = 8192

    disks {
        disk_size         = "10G"
        storage_pool      = "local-lvm"
        type              = "scsi"
    }
    efi_config {
        efi_storage_pool  = "local-lvm"
        efi_type          = "4m"
        pre_enrolled_keys = true
    }
    http_directory           = "cloud-init"
    insecure_skip_tls_verify = true
    
    boot_iso {
        type = "scsi"
        iso_checksum            = "file:https://releases.ubuntu.com/noble/SHA256SUMS"
        iso_file = "local:iso/ubuntu-24.04.2-live-server-amd64.iso"
        unmount = true
        iso_storage_pool = "local"
    }

    network_adapters {
        bridge = "vmbr0"
        model  = "virtio"
    }
    node                 = "scope"
    username             = "root@pam!test"  # <username>@<realm>!<token_id>
    token                = "e77dcf40-17a9-4a12-93a9-d5451450ffeb"
    proxmox_url          = "https://192.168.251.30:8006/api2/json"
    qemu_agent           = true
    communicator         = "ssh"
    ssh_timeout          = "10h"
    ssh_username         = "ubuntu"
    ssh_password         = "ubuntu"
    template_description = "Ubuntu for eBPF course, generated on ${timestamp()}"
    template_name        = "ubuntu-ebpf"
    vm_name = "practice-vm"
}

build {
    sources = ["sources.qemu.practice-vm", "sources.virtualbox-iso.practice-vm", "sources.proxmox-iso.practice-vm"]

    # Setup for development
    provisioner "shell" {
        inline = [
            # Disable auto-dimming the screen
            "gsettings set org.gnome.desktop.session idle-delay 0",

            # Enable dark mode by default
            "gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'",

            # Fix the boot lagging issue (we already have NetworkManager)
            "echo 'ubuntu' | sudo -S systemctl disable systemd-networkd",

            # Patch compiler error
            "echo 'ubuntu' | sudo -S ln -s /usr/include/x86_64-linux-gnu/asm /usr/include/asm",

            # Setup Virtualbox clipboard
            # "echo 'ubuntu' | sudo -S VBoxClient --clipboard",

            # Pull down the required repository
            "git clone https://github.com/easy-ebpf/lab-1 ~/Desktop/lab-1"
        ]
    }

    # Optimize VM size
    provisioner "shell" {
        inline = [
            "echo 'ubuntu' | sudo -S apt-get autoremove",
            "echo 'ubuntu' | sudo -S apt-get clean",
            "echo 'ubuntu' | sudo -S rm -rf /var/log/*",
            "echo 'ubuntu' | sudo -S fstrim /"
        ]
    }
}

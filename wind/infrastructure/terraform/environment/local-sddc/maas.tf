# Imaging Server (MAAS Controller) configuration using Terraform and libvirt provider

# Pool, Volume, and Cloudinit resources for the MAAS controller VM
resource "libvirt_pool" "mini_me_pool" {
  name = "mini-me-pool"
  type = "dir"
  target = {
    path = "/mnt/stones/earth/vms"
  }
}

resource "libvirt_pool" "default" {
  name = "default"
  type = "dir"
  target = {
    path = "/mnt/stones/earth/libvirt/default"
  }
}

# Solving for image hydration during the Terraform apply phase, which is a common issue [SDDC-11] when using cloud images with libvirt.
# 1. The Golden Image (The Source)
resource "libvirt_volume" "ubuntu_noble_base" {
  name   = "ubuntu-noble-base.qcow2"
  pool   = libvirt_pool.mini_me_pool.name
  create = {
    content = {
      url = "file:///mnt/stones/earth/iso/ubuntu-24.04-server-cloudimg-amd64.img"
    }
  }
  target = {
    format = {
      type = "qcow2"
    }
  }
}

# 2. The Working Copy (The Destination)
resource "libvirt_volume" "maas_disk" {
  name   = "maas-root.qcow2"
  pool   = libvirt_pool.mini_me_pool.name
  capacity = 42949672960 #40GB
  target = {
    format = {
      type = "qcow2"
    }
  }
  # This is the key part that tells libvirt to use the existing image as a backing store, which allows for fast provisioning without hydration issues.
  backing_store = {
    path = libvirt_volume.ubuntu_noble_base.path
    format = {
      type = "qcow2"
    }
  }
}

# 3. The Cloudinit Disk (The Customizer)
resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  # This is the magic line that reads your physical file
  user_data = file("${path.module}/user-data")

  # Add this line to pick up your static network settings
  network_config = file("${path.module}/network-config")

  #Metadata is optional, but you can add it if needed
  meta_data = file("${path.module}/meta-data")
  depends_on = [ libvirt_pool.default ]
}

resource "libvirt_domain" "maas_controller" {
  name   = "maas_controller"
  memory = "4194304" # 4GB in KiB
  vcpu   = 2
  type   = "kvm"
  running = true
  autostart = true

  os = {
    type = "hvm"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool = libvirt_pool.mini_me_pool.name
            volume = libvirt_volume.maas_disk.name
          }
        }
      target = {
          dev = "vda"
          bus = "virtio"
        }
      driver = {
          type = "qcow2"
        }
      },
    {
        source = {
          file = {
            file = libvirt_cloudinit_disk.commoninit.path
          }
        }
      target = {
          dev = "hdb"
          bus = "ide"
        }
      driver = {
          type = "raw"
        }
      device = "cdrom"
      }
    ]
    consoles = [
      {
        type = "pty"
        target = {
          type = "serial"
          port = "0"
        }
      }
    ]
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = { 
          bridge = {
            bridge = "br60"
          }
        }
      }
    ]     
  }
}


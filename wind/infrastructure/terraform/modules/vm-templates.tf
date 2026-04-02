# Example logic for the KVM VM on Intel-01
resource "libvirt_domain" "functional_test_vm" {
  name   = "functional_test_vm"
  memory = "4096"
  vcpu   = 2

  network_interface {
  
  }

  disk {
    volume_id = libvirt_volume.functional_test_vm_disk.id
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id
}
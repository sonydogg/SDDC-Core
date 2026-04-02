# SDDC Virtualization Cheat Sheet (Libvirt/KVM)

## 🚀 Common Operations
### List all VMs and their current status
virsh list --all

### Connect to the VM Serial Console (The "Monitor")
### Note: Press 'Enter' once connected to see the login prompt.
### Note: Use 'Ctrl + ]' to exit the console.
virsh console maas_controller

### Show VM network info (MAC address and Bridge)
virsh domiflist maas_controller

### Show VM disk info (Path to .qcow2 on Earth stone)
virsh domblklist maas_controller

## ⚡ Power & Lifecycle

### Start the VM
virsh start maas_controller

### Graceful Shutdown (Sends signal to OS)
virsh shutdown maas_controller

### Force Off (Like pulling the power cable)
virsh destroy maas_controller

### Hard Reset
virsh reset maas_controller

### Wipe VM definition (Does NOT delete the disk file)
virsh undefine maas_controller

# 🛠️ Host & Permission Fixes

### Verify connection to the Hypervisor
virsh uri

### Refresh group permissions (if 'Permission Denied')
newgrp libvirt
newgrp kvm

### Watch VM resource usage in real-time
virt-top
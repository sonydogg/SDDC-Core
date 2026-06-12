# NFS Volume Migration Runbook
**Host:** mini-me-intel-01 (primary) | mini-me-intel-02 (secondary)
**NAS:** sddc-nas / 172.16.16.10 (TrueNAS SCALE)
**Storage Network:** 172.16.16.0/24 (dedicated L2 VLAN, secondary NICs)
**Date Started:** 2026-05-07
**Approach:** Combined Earth + Water migration in a single outage window (Option B — KVM assets go directly to Water, not via /opt temp)

---

## Objective

Migrate all Docker volume and workspace storage from local SSDs to TrueNAS NFS shares. Decouples compute from storage, enables ZFS data protection, and aligns with the Elemental Stones abstraction so application paths stay static as hardware evolves.

---

## NFS Share Layout (TrueNAS)

Dedicated per-purpose datasets — each one its own NFS export, mounted at a purpose-named subpath under the stone:

| Stone | TrueNAS Dataset | NFS Export | Mount Point (Host) | Purpose |
|-------|----------------|------------|-------------------|---------|
| Earth | `Earth/docker_volumes` | `172.16.16.10:/mnt/Earth/docker_volumes` | `/mnt/stones/earth` | Docker volumes (Postgres, n8n, Grafana, proxy) |
| Fire  | `Fire/wind` *(TBD)* | `172.16.16.10:/mnt/Fire/wind` | `/mnt/stones/wind` | Active workspace (Docker config, secrets, Terraform) |
| Water | `Water/KVM` | `172.16.16.10:/mnt/Water/KVM` | `/mnt/stones/water/kvm` | KVM assets — libvirt config, VM disk images, ISOs |
| Water | `Water/P4Depot` | `172.16.16.10:/mnt/Water/P4Depot` | `/mnt/stones/water/p4depots` | Perforce depot archive files (`/depots` in P4D container) |

> `/mnt/stones/water/` itself is a plain local directory containing multiple NFS mount points — there is no single Water mount.

---

## What Stays Local (Never Migrates to NFS)

| Path | Reason |
|------|--------|
| `/opt/perforce/p4data/` | P4D db/journal — local NVMe for performance. Already relocated. |
| OS / boot volume | Obviously |

---

## Pre-Flight Checklist

- [x] P4D health verified — running from `/opt/perforce/p4data/`, 5 changes visible, all depots healthy
- [x] TrueNAS NFS share reachable — `172.16.16.10:/mnt/Earth/docker_volumes` mounts successfully (220G free)
- [x] Storage network connectivity fixed on intel-01 (Cisco 3560 trunk → access port for storage NIC)
- [x] Temp NFS mount verified at `/mnt/nfs_earth`
- [x] KVM asset inventory: ~13GB total (12G vms + 600M iso + 8K libvirt config)
- [x] Local water dirs (`maas_images`, `p4depots`) confirmed empty — nothing to migrate from current `/mnt/stones/water/`
- [x] Libvirt pool inventory:
  - `default` → `/mnt/stones/earth/libvirt/default`
  - `mini-me-pool` → `/mnt/stones/earth/vms`
- [x] Water NFS exports created: `/mnt/Water/KVM`, `/mnt/Water/P4Depot`
- [ ] Fire NFS export created (deferred — Phase 2)

---

## Current State of `/mnt/stones/earth` (Local)

```
github_runner/      → Docker volume (migrate to Earth NFS)
grafana_data/       → Docker volume
maas_db/            → Docker volume — Postgres 16
maas_db_v14/        → Old Postgres 14 data — DELETE after MAAS healthy
n8n_data/           → Docker volume
n8n_db_data/        → Docker volume — Postgres 16
n8n_memory/         → Docker volume
proxy_data/         → Docker volume
proxy_letsencrypt/  → Docker volume
iso/                → 601M — ubuntu-24.04-server-cloudimg-amd64.img → Water NFS
libvirt/            → 8K — pool config dir → Water NFS
vms/                → 12G — maas-root.qcow2 + ubuntu-noble-base.qcow2 → Water NFS
```

---

## Phase 1 — Combined Earth + Water Migration

**Goal:** Move Docker volumes to Earth NFS, KVM assets directly to Water NFS — single outage window.
**Downtime:** Full SDDC outage. P4D + n8n + MAAS controller VM + Grafana all down.

### Step 1.1 — Shut down MAAS controller VM (graceful)
```bash
sudo virsh shutdown maas_controller
# Watch for clean stop
watch -n 2 'sudo virsh list --all'
# Once Status = shut off, Ctrl+C
```

### Step 1.2 — Stop ALL containers
```bash
sudo docker compose -f /mnt/stones/wind/infrastructure/docker/docker-compose.yaml stop
sudo docker ps  # Should be empty
```

### Step 1.3 — Mount Water KVM share at temp location
```bash
sudo mkdir -p /mnt/nfs_water_kvm
sudo mount -t nfs 172.16.16.10:/mnt/Water/KVM /mnt/nfs_water_kvm
df -h /mnt/nfs_water_kvm
```

> P4Depot share doesn't need a temp mount — it's destination-only with no incoming data (post-wipe wind depot lives in `/p4data`, not `/depots`).

### Step 1.4 — Rsync KVM assets from earth → Water/KVM NFS
```bash
sudo rsync -avhP --numeric-ids \
    /mnt/stones/earth/libvirt \
    /mnt/stones/earth/vms \
    /mnt/stones/earth/iso \
    /mnt/nfs_water_kvm/
```

### Step 1.5 — Rsync Docker volumes from earth → Earth NFS
```bash
sudo rsync -avhP --numeric-ids \
    /mnt/stones/earth/github_runner \
    /mnt/stones/earth/grafana_data \
    /mnt/stones/earth/maas_db \
    /mnt/stones/earth/n8n_data \
    /mnt/stones/earth/n8n_db_data \
    /mnt/stones/earth/n8n_memory \
    /mnt/stones/earth/proxy_data \
    /mnt/stones/earth/proxy_letsencrypt \
    /mnt/nfs_earth/
```

### Step 1.6 — Verify ownership preserved on both NFS shares
```bash
ls -lan /mnt/nfs_earth/
# Confirm: n8n_db_data and maas_db owned by 70 (postgres)
# Confirm: grafana_data owned by 472

ls -lan /mnt/nfs_water_kvm/vms/
# Confirm: *.qcow2 files owned by 64055 (libvirt-qemu) and group 108 (kvm)
```

### Step 1.7 — Delete old Postgres 14 debris
```bash
sudo rm -rf /mnt/stones/earth/maas_db_v14
```

### Step 1.8 — Pre-create stone mount points
```bash
sudo mkdir -p /mnt/stones/water/kvm /mnt/stones/water/p4depots
```

### Step 1.9 — Add NFS mounts to fstab
```bash
sudo nano /etc/fstab
```

Add:
```
# Earth — Docker Volumes (NFS)
172.16.16.10:/mnt/Earth/docker_volumes  /mnt/stones/earth         nfs  defaults,_netdev,nfsvers=4,noatime  0  0

# Water/KVM — libvirt config, VM disks, ISOs (NFS)
172.16.16.10:/mnt/Water/KVM             /mnt/stones/water/kvm     nfs  defaults,_netdev,nfsvers=4,noatime  0  0

# Water/P4Depot — Perforce depot archives (NFS)
172.16.16.10:/mnt/Water/P4Depot         /mnt/stones/water/p4depots  nfs  defaults,_netdev,nfsvers=4,noatime  0  0
```

> `_netdev` ensures systemd waits for network before mounting on boot.

### Step 1.10 — Unmount temp mounts and cut over
```bash
sudo umount /mnt/nfs_earth
sudo umount /mnt/nfs_water_kvm

# Mount via fstab at the real stone paths
sudo mount /mnt/stones/earth
sudo mount /mnt/stones/water/kvm
sudo mount /mnt/stones/water/p4depots

# Verify
df -h | grep -E "stones|nfs"
ls -la /mnt/stones/earth/
ls -la /mnt/stones/water/kvm/
ls -la /mnt/stones/water/p4depots/
```

### Step 1.11 — Update libvirt storage pool paths
The pool XMLs still point at `/mnt/stones/earth/...`. Redefine to point at the new Water/KVM mount:

```bash
# Stop and undefine old pools
sudo virsh pool-destroy default
sudo virsh pool-undefine default
sudo virsh pool-destroy mini-me-pool
sudo virsh pool-undefine mini-me-pool

# Recreate pointing at Water/KVM NFS
sudo virsh pool-define-as default dir --target /mnt/stones/water/kvm/libvirt/default
sudo virsh pool-start default
sudo virsh pool-autostart default

sudo virsh pool-define-as mini-me-pool dir --target /mnt/stones/water/kvm/vms
sudo virsh pool-start mini-me-pool
sudo virsh pool-autostart mini-me-pool

sudo virsh pool-list --all
```

### Step 1.12 — Update maas_controller VM disk path
The VM XML still references `/mnt/stones/earth/vms/maas-root.qcow2`:

```bash
sudo virsh edit maas_controller
# Find the disk source path and change:
#   <source file='/mnt/stones/earth/vms/maas-root.qcow2'/>
# to:
#   <source file='/mnt/stones/water/kvm/vms/maas-root.qcow2'/>
```

### Step 1.13 — Restart containers
```bash
sudo docker compose -f /mnt/stones/wind/infrastructure/docker/docker-compose.yaml up -d
sudo docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Step 1.14 — Restart MAAS controller VM
```bash
sudo virsh start maas_controller
sudo virsh list --all
# Watch for state = running
```

### Step 1.15 — Smoke test
```bash
# Containers
sudo docker compose -f /mnt/stones/wind/infrastructure/docker/docker-compose.yaml logs --tail=50 \
    n8n n8n-db grafana nginx-proxy maas-db perforce

# n8n / Grafana / proxy
curl -k https://n8n.ethicalitllc.com 2>&1 | head -20
curl -k https://grafana.ethicalitllc.com 2>&1 | head -20

# P4D
p4 -p 172.16.16.30:1666 info
p4 -p 172.16.16.30:1666 changes -m 5

# MAAS controller VM (after boot)
ping <maas-controller-ip>
```

### Step 1.16 — Reboot test
```bash
sudo reboot
# After reboot:
df -h | grep stones
sudo docker ps
sudo virsh list --all
```

---

## Phase 2 — Wind NFS Migration (Active Workspace)

> **Prerequisite:** Fire NFS share must be created on TrueNAS first.

**Goal:** Move Docker config, secrets, Terraform, MeshCentral data from local to Fire NFS.

### Step 2.1 — Create Fire NFS export on TrueNAS
- TrueNAS UI → Shares → NFS → Add
- Dataset: `Fire/wind`
- Path: `/mnt/Fire/wind`
- Allowed hosts: `172.16.16.20, 172.16.16.30`

### Step 2.2 — Temp mount and rsync
```bash
sudo mkdir -p /mnt/nfs_wind
sudo mount -t nfs 172.16.16.10:/mnt/Fire/wind /mnt/nfs_wind

# Stop everything that touches /mnt/stones/wind/ — that's all containers
# (compose file lives there; secrets are bind-mounted from there)
sudo docker compose -f /mnt/stones/wind/infrastructure/docker/docker-compose.yaml stop

sudo rsync -avhP --numeric-ids /mnt/stones/wind/ /mnt/nfs_wind/
```

### Step 2.3 — Add Wind NFS to fstab and cut over
```bash
# Add to /etc/fstab:
# 172.16.16.10:/mnt/Fire/wind  /mnt/stones/wind  nfs  defaults,_netdev,nfsvers=4,noatime  0  0

sudo umount /mnt/nfs_wind
sudo mount /mnt/stones/wind
sudo docker compose -f /mnt/stones/wind/infrastructure/docker/docker-compose.yaml up -d
```

---

## Phase 3 — Intel-02 Host Preparation (Container + VM Capable)

**Goal:** Bring intel-02 up to parity with intel-01 — same NFS mounts, same KVM/libvirt stack with NFS-compatible config, same Docker capability. This makes intel-02 a viable failover/secondary host without touching workloads currently running on intel-01.

### Step 3.1 — NFS Mounts

Pre-create mount points:
```bash
sudo mkdir -p /mnt/stones/earth /mnt/stones/water/kvm /mnt/stones/water/p4depots /mnt/stones/wind
```

Add to `/etc/fstab`:
```
172.16.16.10:/mnt/Earth/docker_volumes  /mnt/stones/earth           nfs  defaults,_netdev,nfsvers=4,noatime  0  0
172.16.16.10:/mnt/Water/KVM             /mnt/stones/water/kvm       nfs  defaults,_netdev,nfsvers=4,noatime  0  0
172.16.16.10:/mnt/Water/P4Depot         /mnt/stones/water/p4depots  nfs  defaults,_netdev,nfsvers=4,noatime  0  0
172.16.16.10:/mnt/Fire/Wind             /mnt/stones/wind            nfs  defaults,_netdev,nfsvers=4,noatime  0  0
```

```bash
sudo systemctl daemon-reload
sudo mount -a
df -h | grep stones
```

### Step 3.2 — Install KVM, libvirt, Docker

```bash
# Inventory what's there
which qemu-system-x86_64 virsh docker 2>&1

# KVM + libvirt stack
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst cpu-checker

# Docker (skip if installed)
curl -fsSL https://get.docker.com | sudo sh

# Verify CPU supports KVM
sudo kvm-ok
```

Expected `kvm-ok` output: `KVM acceleration can be used`.

### Step 3.3 — Group Membership (avoid sudo for virsh/docker)

```bash
sudo usermod -aG libvirt,kvm,docker $USER

# Log out and back in, or for this session only:
newgrp libvirt
```

Verify:
```bash
id | tr ',' '\n' | grep -E "libvirt|kvm|docker"
```

### Step 3.4 — libvirt qemu.conf overrides (CRITICAL for NFS-backed VMs)

These are the gotchas we hit on intel-01. Apply BEFORE the first VM start attempt:

```bash
sudo tee -a /etc/libvirt/qemu.conf > /dev/null <<'EOF'

# SDDC: required for KVM disks living on NFS shares
# security_driver="apparmor" + remember_owner=1 (defaults) cause silent permission failures on NFS.
# These overrides keep dynamic_ownership=1 working without the AppArmor/XATTR landmines.
security_driver = "none"
remember_owner = 0
EOF

sudo systemctl restart libvirtd
sudo systemctl status libvirtd --no-pager | head -5
```

### Step 3.5 — VLAN60 Bridge

For VMs to join the MAAS imaging VLAN (192.168.60.0/24), intel-02 needs the same bridge topology as intel-01 — but on a different IP to avoid collision.

First confirm intel-02's PCIe NIC name:
```bash
ip -br link show
# Look for the upstream-connected NIC (often enp4s0 or similar)
```

Edit `/etc/netplan/50-cloud-init.yaml` and add (adjust NIC name as needed):
```yaml
  vlans:
    vlan60:
      id: 60
      link: enp4s0  # ← intel-02's PCIe NIC
  bridges:
    br60:
      interfaces: [vlan60]
      addresses:
        - 192.168.60.2/24  # different from intel-01's 192.168.60.1
      dhcp4: no
```

Apply:
```bash
sudo netplan apply
ip addr show br60
```

### Step 3.6 — Define libvirt Storage Pools

Pools point at the shared Water/KVM NFS path. The actual qcow2 files already live there from intel-01's setup — intel-02 just needs the pool definitions to see them.

```bash
sudo virsh pool-define-as default dir --target /mnt/stones/water/kvm/libvirt/default
sudo virsh pool-start default
sudo virsh pool-autostart default

sudo virsh pool-define-as mini-me-pool dir --target /mnt/stones/water/kvm/vms
sudo virsh pool-start mini-me-pool
sudo virsh pool-autostart mini-me-pool

# Verify both pools active and see the existing volumes
sudo virsh pool-list --all
sudo virsh vol-list mini-me-pool
```

`vol-list mini-me-pool` should show `maas-root.qcow2` and `ubuntu-noble-base.qcow2`.

### Step 3.7 — Safety Boundary

> **Critical concurrency rule:** intel-01 currently owns the running `maas_controller` VM using qcow2 files on shared NFS. Defining pools on intel-02 grants read access to the same files — **do NOT start `maas_controller` on intel-02 while it's running on intel-01.** Concurrent qcow2 writes from two hypervisors will corrupt the disk irrecoverably.
>
> Treat intel-02 as a passive standby until you intentionally migrate (Step 3.9).

### Step 3.8 — Smoke Test

```bash
# libvirt connection works without sudo
virsh list --all

# Docker works without sudo
docker ps
docker run --rm hello-world

# NFS mounts persist on reboot
sudo reboot
# After reboot:
df -h | grep stones
sudo docker ps
sudo virsh pool-list --all
```

### Step 3.9 — (Optional) Test Failover Workflow

Once you want to validate that intel-02 can actually take over a workload from intel-01, here's the manual VM failover sequence:

```bash
# On intel-01: gracefully stop the VM
sudo virsh shutdown maas_controller

# Wait for it to fully stop
sudo virsh list --all  # should show "shut off"

# On intel-02: start the same VM using shared NFS-backed disk
# (Domain XML needs to exist on intel-02 first — see notes below)
sudo virsh start maas_controller
sudo virsh list --all  # should show "running"
```

To make intel-02 aware of the domain (one-time setup):
```bash
# On intel-01: export the domain XML
sudo virsh dumpxml maas_controller > /mnt/stones/wind/infrastructure/libvirt/maas_controller.xml

# On intel-02: define the domain from the shared XML
sudo virsh define /mnt/stones/wind/infrastructure/libvirt/maas_controller.xml
sudo virsh list --all  # domain appears, shut off
```

This is cold failover. For live migration (zero downtime), see the failover notes section below.

---

## Validation Checklist (Post-Migration)

- [ ] All three stone paths NFS-backed (`df -h | grep stones`)
- [ ] All Docker containers healthy (`docker ps`)
- [ ] n8n accessible at https://n8n.ethicalitllc.com
- [ ] Grafana accessible at https://grafana.ethicalitllc.com
- [ ] P4D accessible: `p4 -p 172.16.16.30:1666 info` returns clean
- [ ] MAAS controller VM running and reachable
- [ ] libvirt pools active and pointing at Water NFS
- [ ] Reboot intel-01 — all NFS mounts come up, all containers + VMs start
- [ ] Reboot intel-02 — NFS mounts come up

---

## Rollback

If any phase fails:
1. Stop containers: `docker compose stop`
2. Remove or comment out the fstab entry for the failed stone
3. `sudo umount /mnt/stones/<stone>`
4. The local data on the original disk is intact (we rsync'd, didn't move)
5. Restart containers — they'll pick up the original local paths
6. Investigate what went wrong before retrying

> **Critical:** Do NOT delete the local data on `/mnt/stones/earth/` until at least one full reboot test succeeds with NFS-backed mounts.

---

## Post-Migration Cleanup (After Verified Stable)

Once Phase 1 has survived a reboot and 24-48 hours of normal operation:

```bash
# These steps wipe the OLD local data — only run after NFS is proven stable
sudo umount /mnt/stones/earth  # Briefly, to access the underlying local fs
sudo rm -rf /mnt/stones/earth/*  # Local data — already on NFS
sudo mount /mnt/stones/earth  # Remount NFS
```

Better: leave the local copies for a week as a fallback, then clean.

---

## Open Items / ADR Debt

- [ ] ADR: Storage architecture final state (revised stone mapping + ZFS topology)
- [ ] ADR: MAAS deployment method (VM vs Docker compose)
- [ ] ADR: OOB management strategy (AMT, MeshCentral, JetKVM)
- [ ] n8n ADR watcher: update path from `docs/` to `wind/ADRs/`
- [ ] Samsung 883 3.84TB role decision (expand Earth mirror, cold spare, or backup pool)

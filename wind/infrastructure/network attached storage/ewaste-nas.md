# System Design Document: Lenovo M93p SFF "Cram" NAS
**Project Title:** SDDC Storage Node (The Elemental Stone)
**Platform:** Lenovo ThinkCentre M93p SFF (Intel Q87 Chipset)
**OS:** TrueNAS SCALE

---

## 1. Hardware Inventory
| Component | Specification | Notes |
| :--- | :--- | :--- |
| **CPU** | Intel Core i5-4570 | 4C/4T @ 3.20GHz |
| **Cooler** | Noctua NH-L9i | **Critical:** 37mm height for drive cage clearance |
| **RAM** | 20GB Mixed DDR3 | 2x8GB G.Skill + 2x2GB (Old School Triple Channel kit) |
| **Networking** | 10Gtek 2.5Gbps NIC | Realtek RTL8125BG (PCIe x1 slot) |
| **NVMe Adapter** | Low-Profile PCIe x16 | Houses the Crucial P3 |

---

## 2. Storage Hierarchy (The Tiers)

### Tier 1: Hot / App Pool
* **Hardware:** 2x Samsung 870 EVO 250GB SSDs
* **Config:** ZFS Mirror (vdev)
* **Purpose:** TrueNAS Apps, Docker Containers, and active local work.

### Tier 2: Metadata / Cache
* **Hardware:** Crucial P3 500GB NVMe M.2
* **Config:** Special VDEV (Metadata) or L2ARC
* **Purpose:** Speed up file browsing and small-block IO for Mac M1 backups.

### Tier 3: Cold Storage
* **Hardware:** 1x 4TB Seagate IronWolf (3.5")
* **Config:** Single-disk VDEV (Mass Storage)
* **Purpose:** Long-term archival, media, and time machine targets.

### Tier 4: Arctic / Offsite
* **Target:** Azure Blob Storage
* **Mechanism:** TrueNAS Cloud Sync Tasks
* **Purpose:** Disaster recovery and long-term immutable storage.

---

## 3. Physical "Cram" Mapping
* **Main 3.5" Bay:** 4TB IronWolf (Requires Blue Tool-less Caddy #03T9903).
* **Internal 2.5" Bay:** Samsung 870 EVO #1 (Requires Metal Bracket #54Y9397).
* **Optical Bay (9.5mm):** Vantec Caddy housing the SanDisk 256GB (Boot Drive).
* **The "Sandwich" (Optional):** Second Samsung EVO mounted via VHB tape or dual-bracket near the front intake.

---

## 4. Critical Assembly & "Gotchas"
* **Fan Header:** Lenovo uses a **5-pin proprietary header**. Use the 5-to-4 pin adapter for the Noctua NH-L9i.
* **Thermal Management:** Do not adhesive-sandwich SSDs directly. Ensure a **3mm air gap** for the 80mm Noctua exhaust fan to pull air through.
* **Power:** 240W PSU is sufficient, but requires **SATA Power Y-Splitters** to reach all 4 SATA devices.
* **Cabling:** Use **90-degree SATA data cables** to clear the swinging drive cage.
* **Network:** Cisco 3560 SFP+ port requires `service unsupported-transceiver` and a 10G/Multi-Gig SFP+ to RJ45 module.

---

## 5. TrueNAS Post-Install Checklist
1. [ ] Update BIOS to latest (for NVMe/RAM stability).
2. [ ] Set SATA mode to **AHCI** in BIOS.
3. [ ] Disable "Fan Error" halt in BIOS (Noctua low RPM warning).
4. [ ] Create "Main" pool on IronWolf.
5. [ ] Attach Crucial P3 as **Metadata Special VDEV** to Main pool.
6. [ ] Create "App" pool on mirrored Samsung EVOs.
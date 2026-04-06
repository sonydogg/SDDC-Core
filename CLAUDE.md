# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SDDC-Core is a Software Defined Data Center (SDDC) framework running on an Intel Mini cluster. It uses a GitOps model to automate infrastructure provisioning and documentation lifecycle. The `wind/` directory is the Git-tracked subset of a larger Perforce workspace.

## Common Commands

### Docker (Core Services)
```bash
cd wind/infrastructure/docker
docker-compose up -d          # Start all services
docker-compose down           # Stop all services
docker-compose logs -f <svc>  # Tail logs for a service
```

### Terraform
```bash
# Each environment is independent — init/plan/apply per directory
cd wind/infrastructure/terraform/environment/local-sddc
terraform init && terraform plan && terraform apply

cd wind/infrastructure/terraform/environment/cloud-azure
terraform init && terraform plan && terraform apply

cd wind/infrastructure/terraform/applications/<app>
terraform init && terraform plan && terraform apply
```

### Environment Setup
```bash
# Load Azure service principal credentials before Terraform
source /mnt/stones/wind/secrets/terraform-sp.env   # exports ARM_* vars

# Load Docker/Perforce credentials
source /mnt/stones/wind/.env
```

### KVM / libvirt
```bash
virsh list --all
virsh console <vm-name>
# See wind/docs/libvirt-quick.md for a full cheatsheet
```

### Perforce + Git Workflow
```bash
# Edit files through Perforce first
p4 edit <filename>
# ... make changes ...
p4 submit -d "Description"

# Then sync to Git
git add . && git commit -m "..." && git push origin main
```

**Hybrid workflow note:** Perforce is the primary iteration environment. Files are submitted to P4 first during active development, then periodically pulled into Git. As a result, the Git working tree may show uncommitted changes, deleted files, or apparent duplicates that are mid-flight between P4 submit and Git commit. Do not treat these as errors — they reflect normal in-progress state in the hybrid workflow. When reviewing code, ask before assuming something is a bug vs. an uncommitted iteration.

**Claude editing protocol:** Perforce sets files to read-only after submit. Before using any Edit or Write tool on a file inside `wind/`, Claude must first run `p4 edit <file_path>` via Bash to unlock it. Do not attempt to edit a `wind/` file without running `p4 edit` first. After edits are complete, Claude stops — Trevor reviews and runs `p4 submit -d "description"` to re-lock and record in P4 history before committing to Git.

## Architecture

### Storage Hierarchy ("Elemental Stones" — ADR-002)
Physical paths on the host map to logical performance tiers:
- `/mnt/stones/earth/` — persistent bulk storage (Perforce depot, VM images)
- `/mnt/stones/wind/` — active workspace (Docker config, secrets, Terraform state)
- `/mnt/stones/water/` — fast ephemeral storage

Docker volumes and Terraform state reference these mount points directly.

### Dual Version Control (ADR-020)
- **Perforce (P4D)** — source of truth for heavy assets (VM images, private configs). Server: `mini-me-intel-01.local:1666`, client: `sddc_architect_ws`
- **Git / GitHub** — sanitized code and IaC (this repo). Perforce submits gate Git commits.

### Docker Services (`wind/infrastructure/docker/docker-compose.yaml`)
Seven services on a single compose stack:
- **P4D** (port 1666) — Perforce server
- **n8n** (port 5678) + **PostgreSQL 16** — automation engine and its database
- **Nginx Proxy Manager** (80/443/81) — reverse proxy with SSL termination
- **Cloudflared** — Cloudflare tunnel for external access
- **MAAS** — bare-metal provisioning for KVM guests
- **Grafana** (port 3000) — dashboards with Azure Entra SSO

Custom MACVLAN network `imaging_vlan60` (192.168.60.0/24) for MAAS PXE boot.
Secrets are mounted via Docker secrets from `wind/infrastructure/docker/secrets/`.

### Terraform Environments
| Directory | Provider | Purpose |
|-----------|----------|---------|
| `environment/local-sddc/` | `libvirt` + `maas` | KVM VMs and MAAS provisioning on the Intel Mini |
| `environment/cloud-azure/` | `azurerm` | Azure Monitor, Log Analytics, Update Manager |
| `environment/cloud-gcp/` | (stub) | Future GCP resources |
| `applications/grafana-azure-entra-sso/` | `grafana` | Grafana SSO via Azure Entra ID |
| `applications/azure-monitor-connectors/` | `azurerm` | Azure Monitor data connectors |

Credentials are never committed — they live in `terraform.tfvars` (gitignored) or ARM_* environment variables.

### n8n GitOps Pipeline
The automation brain (ADR-007): n8n monitors GitHub for changes to `wind/ADRs/*.md`, validates against Confluence, gates with a Gmail approval step, then creates or updates Confluence pages. It handles orphaned-page recovery automatically.

### Architecture Decision Records
All major decisions are documented in `wind/ADRs/` as numbered ADR-NNN files. Before making significant infrastructure or tooling changes, check existing ADRs and create a new one if the change represents a new architectural direction. Use the template at `wind/ADRs/ADR-template.md`.

## Secrets Locations
- Docker secrets: `wind/infrastructure/docker/secrets/` (gitignored)
- Terraform credentials: `terraform.tfvars` per environment (gitignored) or `ARM_*` env vars
- `.env` template: `wind/infrastructure/docker/template.env`

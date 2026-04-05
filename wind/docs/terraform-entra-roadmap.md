# Terraform + Entra Learning Roadmap

**Owner:** Trevor Long — Principal Enterprise Architect, ZeniMax Media  
**Status:** Active  
**Created:** 2026-04-04  
**Location:** `/mnt/stones/wind/learning/terraform-entra-roadmap.md`

---

## Purpose

A living document tracking a structured learning path for Terraform applied to Microsoft Entra ID (Azure AD). The goal is to build patterns of working that can be adopted at enterprise scale: a preprod → prod pipeline with code review, impact validation, and enforcement baked in.

This roadmap is informed by existing lab work documented in ADR-001, ADR-007, and ADR-020, and draws on 25 years of identity and infrastructure experience — from Active Directory administration to Principal Enterprise Architect. The discipline here is not learning identity. It is learning to **codify identity decisions as infrastructure**.

---

## Authentication Strategy (Resolved Early — Session 1)

Before any stage begins, the authentication context must be explicit. This was surfaced in Session 1 when an Arc-onboarded machine's managed identity was picked up automatically by the AzureAD provider.

### The Problem
Terraform inherits credential context from the environment. On an Arc machine, this means the managed identity is discovered and used by default — even when you intend to use a dedicated service principal. This caused an unintended auth context in early Terraform runs.

### The Resolution
Override explicitly using ARM environment variables before any `terraform` command:

```bash
export ARM_CLIENT_ID="<sp-client-id>"
export ARM_CLIENT_SECRET="<sp-client-secret>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

Store these in a `.env` file in `/mnt/stones/wind/secrets/` (already covered by `.gitignore` and `.p4ignore` per ADR-020). Source before running:

```bash
source /mnt/stones/wind/secrets/terraform-sp.env
terraform plan
```

### Service Principal Inventory (maintain this)

| Name | Purpose | Least-Privilege Scope |
|------|----------|-----------------------|
| sp-terraform-read | Entra reads, data sources, import | Directory.Read.All |
| sp-terraform-provision | Resource creation and updates | Directory.ReadWrite.All (scoped) |
| sp-arc-onboarding | Arc machine onboarding | Azure Arc-specific roles only |
| sp-grafana-sso | Grafana OIDC/SSO | openid, profile, email |
| sp-grafana-azure-monitor-connection | Grafana Azure Monitor Connection | subscription 'Hybrid Lab' Read |

> **Rule:** One service principal per concern. Never reuse across pipeline stages. The Terraform provisioning SP should be the only credential that can write to Entra from the pipeline.

### Note for later 4/4/26 8PM

> **shower throughts** Naming convention should be enforced during linting process. As well as permissions. What you see is what you get. I am aligning service princpals to proposed naming convention. My first Terraform target should be mastering the recording of service principals and their permissions. Establish remediation branch. Then the merge from that branch would 'remediate' the nameing and permissions. It allows engineers to know the state.

### Provider Block Pattern (pin the version)

```hcl
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53"  # Pin. The v2→v3 schema changes are breaking.
    }
  }
}

provider "azuread" {
  # Reads from ARM_* environment variables automatically.
  # No credentials in code. Ever.
}
```
> Complete. Pinned Provider block for azuread to 2.53
---

## Stage 1 — HCL Foundations + Schema Clarity

**Status:** 🔲 Not started  
**Objective:** Solve the `[]` vs `{}` problem permanently. Build the mental model for all future provider work.

### The Core Rule
- `{}` = an **object/map** — a single thing with named attributes
- `[]` = a **list** — an ordered collection of things
- `[{}]` = a **list of objects** — what most provider block schemas use for repeatable sub-resources

Your `maas.tf` already demonstrates this correctly: `disks = [ { source = { ... } } ]` is a list of disk objects. The confusion is that some providers use block syntax (no `=`) and some use attribute syntax (with `=`). The provider schema docs always tell you which.

### Modules in this Stage

**HCL types: string, number, bool, list, map, object**  
Internalize when each is appropriate. Pay attention to `type` constraints in variable declarations — they enforce schema discipline across your modules.

**Resource vs data blocks**  
`resource` blocks CREATE and manage. `data` blocks READ existing things without owning them. For Entra, you will use `data` sources heavily to reference existing users and groups without recreating them. Critical distinction for import work.

**Variables, locals, and outputs**  
- `var.*` — inputs, defined in `variables.tf`, supplied via `.tfvars` or env vars  
- `local.*` — derived values computed once and reused, defined in `locals {}` blocks  
- `output` blocks — expose values to other modules or for human inspection after apply  

Establish this file structure discipline now before configs grow large:
```
/module-name/
  variables.tf
  main.tf
  locals.tf
  outputs.tf
```

**Provider version pinning**  
The AzureAD provider changed dramatically between v2 and v3. Use `~> 2.53` (or your tested version) and do not upgrade without reading the changelog. Version drift is a silent killer in long-lived repos.

### Key Resources
- https://developer.hashicorp.com/terraform/language/expressions/types
- https://registry.terraform.io/providers/hashicorp/azuread/latest/docs
- https://developer.hashicorp.com/terraform/language/values/variables

### Session Notes
<!-- Add notes here after each working session -->

---

## Stage 2 — Entra Read: Import Existing State

**Status:** 🔲 Not started  
**Objective:** Map your tenant completely using data sources and import blocks. Touch nothing. Know everything.

### The Principle
This mirrors ADR-007's Check-Then-Act pattern. Read before you write. The `terraform plan` output after import is your discovery artifact — treat it like a network diagram.

### Modules in this Stage

**Data sources: users, groups, apps, service principals**  
```hcl
data "azuread_user" "example" {
  user_principal_name = "trevor@ethicalitllc.com"
}

data "azuread_group" "example" {
  display_name = "SG-Infrastructure"
}
```
Use data sources to build a read-only inventory. Output the IDs, display names, and object types. This becomes your Entra map.

**Import blocks (TF 1.5+)**  
```hcl
import {
  to = azuread_group.infrastructure
  id = "<object-id-from-portal>"
}
```
Import blocks belong in `.tf` files and go through Perforce + Git review — this is the enterprise-grade approach. CLI `terraform import` is for one-offs only.

**State inspection**  
```bash
terraform state list                          # See all managed resources
terraform state show azuread_group.infra      # Full state of one resource
terraform state pull > state-snapshot.json    # Audit snapshot
```

**Config generation from existing resources**  
```bash
terraform plan -generate-config-out=generated.tf
```
Available in TF 1.5+. Produces imperfect but useful starter configs from imported resources. Always review and clean up before committing.

### Key Resources
- https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/user
- https://developer.hashicorp.com/terraform/language/import
- https://developer.hashicorp.com/terraform/tutorials/state/state-import

### Session Notes
<!-- Add notes here after each working session -->

---

## Stage 3 — Modules + Workspace Patterns

**Status:** 🔲 Not started  
**Objective:** Build the reusable module library and the preprod → prod state separation.

### The Architecture
This maps directly to ADR-020's Stones architecture:

| Stone | Terraform Role |
|-------|---------------|
| Wind (`/mnt/stones/wind`) | Module source code, `.tf` files, `.tfvars` per environment |
| Earth (`/mnt/stones/earth`) | Remote state backend (Azure Storage Account) |
| Water | Not directly relevant to Terraform state |

### Modules in this Stage

**Module structure**  
A module is a reusable, versioned decision in code — the Terraform equivalent of an ADR. Example `entra-security-group` module:
```
/modules/entra-security-group/
  variables.tf    # name, description, owners (list), members (list)
  main.tf         # azuread_group resource + member assignments
  outputs.tf      # object_id, display_name
```
Call it per environment with different inputs. The logic lives once.

**Workspaces for environment separation**  
```bash
terraform workspace new preprod
terraform workspace new prod
terraform workspace select preprod
```
Use `terraform.workspace` in locals to branch behavior:
```hcl
locals {
  env_suffix = terraform.workspace == "prod" ? "" : "-${terraform.workspace}"
}
```

**tfvars per environment**  
```
preprod.tfvars
prod.tfvars
```
```bash
terraform apply -var-file=preprod.tfvars   # Explicit. Never implicit.
```
No secrets in tfvars. Secrets stay in `.env` files (see Authentication section above).

**Remote state with Azure Storage**  
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate<unique>"
    container_name       = "tfstate"
    key                  = "entra/${terraform.workspace}.tfstate"
  }
}
```
Enables state locking, team collaboration, and the audit trail required for change management. Fits within Azure free tier for small state files.

### Key Resources
- https://developer.hashicorp.com/terraform/language/modules/develop
- https://developer.hashicorp.com/terraform/cli/workspaces
- https://developer.hashicorp.com/terraform/language/settings/backends/azurerm

### Session Notes
<!-- Add notes here after each working session -->

---

## Stage 4 — Policy Enforcement + Change Governance

**Status:** 🔲 Not started  
**Objective:** The pipeline becomes the change manager. Code review is the approval gate. Drift detection is the audit log.

### The Vision
This is your ADR frontmatter inspection concept made operational. The CI/CD pipeline inspects state the way your n8n workflow inspects Entra. If the plan shows drift from the declared configuration, it alerts. If the plan violates a policy, it blocks. Human approval is required before `apply` runs against `prod`.

### Modules in this Stage

**Variable validation and lifecycle preconditions**  
```hcl
variable "group_owners" {
  type = list(string)
  validation {
    condition     = length(var.group_owners) >= 1
    error_message = "Every security group must have at least one owner."
  }
}
```
Free, no extra tooling. This is policy encoded directly in HCL.

**Azure Policy + Terraform**  
Use `azurerm_policy_definition` and `azurerm_policy_assignment` to enforce standards at the Azure control plane. Config that violates policy gets rejected by Azure itself — not just by Terraform. A second enforcement layer.

**GitHub Actions pipeline: plan → review → apply**  
```
On PR open:
  → terraform fmt --check
  → terraform validate
  → terraform plan -var-file=preprod.tfvars
  → Post plan output as PR comment
  → Require 1 approval

On PR merge to main:
  → terraform apply -var-file=preprod.tfvars (preprod)
  → Manual approval gate
  → terraform apply -var-file=prod.tfvars (prod)
```
This mirrors the ADR publishing workflow exactly: markdown PR → review → merge → publish. Here: `.tf` PR → review → merge → apply.

**Drift detection**  
Scheduled GitHub Actions job:
```yaml
- name: Detect drift
  run: terraform plan -detailed-exitcode
  # Exit code 2 = drift detected → trigger alert
```
Wire the alert to n8n, email, or Teams. The pipeline becomes the compliance reporter.

### Key Resources
- https://developer.hashicorp.com/terraform/language/expressions/custom-conditions
- https://github.com/features/actions
- https://docs.microsoft.com/azure/governance/policy/overview

### Session Notes
<!-- Add notes here after each working session -->

---

## Session Log

| Date | Stage | Topics Covered | Decisions Made |
|------|-------|---------------|----------------|
| 2026-04-04 | Foundation | Roadmap scoped. Auth strategy resolved. ARM variable override pattern documented. SP inventory approach established. | Use `sp-terraform-read` for Stage 2 data source work. Source `.env` before every Terraform run. Pin AzureAD provider at `~> 2.53`. |

---

## Open Questions

- [ ] Confirm AzureAD provider version currently installed in lab
- [ ] Validate `sp-terraform-read` has `Directory.Read.All` and not broader scope
- [ ] Decide: separate state storage account per environment, or one account with path-keyed containers?
- [ ] Confirm TF version in lab (`terraform version`) — need 1.5+ for import blocks

---

## Decisions Made (Compact Reference)

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Use ARM env vars to override managed identity auth | Arc machine identity was picked up automatically; explicit override required |
| D2 | One service principal per concern | Least privilege, auditability, no cross-stage credential reuse |
| D3 | Pin AzureAD provider at `~> 2.53` | v2→v3 has breaking schema changes |
| D4 | Import blocks over CLI import | Code-reviewed, version-controlled, repeatable |
| D5 | Azure Storage for remote state | Enables locking and team collaboration; fits free tier |
| D6 | GitHub Actions for pipeline | Free tier sufficient; mirrors existing ADR publishing workflow |

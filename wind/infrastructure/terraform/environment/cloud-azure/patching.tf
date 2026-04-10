# ── Azure Update Manager — Security Patching Schedule ─────────────────────────
#
# Applies security-only patches to all Linux Arc machines in the SDDC resource
# group. Two maintenance windows per week: Tuesday and Thursday after 11 PM ET.
# Periodic assessment runs automatically so Update Manager knows what's pending
# before each window opens.
#
# Reboot policy: IfRequired — only reboots if a patch requires it.

resource "azurerm_maintenance_configuration" "security_patches" {
  name                     = "sddc-security-patches"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  scope                    = "InGuestPatch"
  in_guest_user_patch_mode = "User"

  install_patches {
    linux {
      classifications_to_include = ["Security", "Critical"]
    }
    reboot = "IfRequired"
  }

  # Tuesday 11 PM ET, 3-hour window
  window {
    start_date_time = "2026-04-14 23:00"
    duration        = "03:00"
    recur_every     = "1Week Tuesday"
    time_zone       = "Eastern Standard Time"
  }
}

# Thursday window — separate configuration, same policy
resource "azurerm_maintenance_configuration" "security_patches_thursday" {
  name                     = "sddc-security-patches-thu"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  scope                    = "InGuestPatch"
  in_guest_user_patch_mode = "User"

  install_patches {
    linux {
      classifications_to_include = ["Security", "Critical"]
    }
    reboot = "IfRequired"
  }

  # Thursday 11 PM ET, 3-hour window
  window {
    start_date_time = "2026-04-16 23:00"
    duration        = "03:00"
    recur_every     = "1Week Thursday"
    time_zone       = "Eastern Standard Time"
  }
}

# ── Dynamic scope assignments ──────────────────────────────────────────────────
# Targets all Linux Arc machines in the SDDC resource group automatically.
# New machines added to the RG are picked up without any config change.

resource "azurerm_maintenance_assignment_dynamic_scope" "tuesday" {
  name                         = "sddc-patch-scope-tue"
  maintenance_configuration_id = azurerm_maintenance_configuration.security_patches.id

  filter {
    resource_groups = [var.resource_group_name]
    os_types        = ["Linux"]
  }
}

resource "azurerm_maintenance_assignment_dynamic_scope" "thursday" {
  name                         = "sddc-patch-scope-thu"
  maintenance_configuration_id = azurerm_maintenance_configuration.security_patches_thursday.id

  filter {
    resource_groups = [var.resource_group_name]
    os_types        = ["Linux"]
  }
}

# Required because this arc server was onboarded manually before the DCR was created. If we don't do this, the AMA agent won't have permissions to send data to the Log Analytics workspace.
data "azurerm_arc_machine" "intel_01" {
  name                = "mini-me-intel-01"
  resource_group_name = var.resource_group_name
}
resource "azurerm_role_assignment" "arc_metrics_publisher" {
  scope                = azurerm_log_analytics_workspace.sddc_logs.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = data.azurerm_arc_machine.intel_01.identity[0].principal_id
}

# 1. Install the AMA Extension on the Intel Mini
resource "azurerm_arc_machine_extension" "ama" {
  name                 = "AzureMonitorLinuxAgent"
  arc_machine_id       = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.HybridCompute/machines/mini-me-intel-01"
  location             = var.location
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
}

# 2. Create the Data Collection Rule (The Brain)
resource "azurerm_monitor_data_collection_rule" "sddc_dcr" {
  name                = "sddc-linux-metrics-dcr"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.sddc_logs.id
      name                  = "sddc-logs-destination"
    }
  }
  data_flow {
    destinations       = ["sddc-logs-destination"]
    output_stream      = "Microsoft-Perf"
    streams            = ["Microsoft-Perf"]
    transform_kql      = "source"
  }
  data_flow {
    destinations       = ["sddc-logs-destination"]
    output_stream      = "Microsoft-Syslog"
    streams            = ["Microsoft-Syslog"]
    transform_kql      = "source"
  }
  data_sources {
    performance_counter {
      counter_specifiers            = ["Processor(*)\\% Processor Time", "Processor(*)\\% Idle Time", "Processor(*)\\% User Time", "Processor(*)\\% Nice Time", "Processor(*)\\% Privileged Time", "Processor(*)\\% IO Wait Time", "Processor(*)\\% Interrupt Time", "Memory(*)\\Available MBytes Memory", "Memory(*)\\% Available Memory", "Memory(*)\\Used Memory MBytes", "Memory(*)\\% Used Memory", "Memory(*)\\Pages/sec", "Memory(*)\\Page Reads/sec", "Memory(*)\\Page Writes/sec", "Memory(*)\\Available MBytes Swap", "Memory(*)\\% Available Swap Space", "Memory(*)\\Used MBytes Swap Space", "Memory(*)\\% Used Swap Space", "Process(*)\\Pct User Time", "Process(*)\\Pct Privileged Time", "Process(*)\\Used Memory", "Process(*)\\Virtual Shared Memory", "Logical Disk(*)\\% Free Inodes", "Logical Disk(*)\\% Used Inodes", "Logical Disk(*)\\Free Megabytes", "Logical Disk(*)\\% Free Space", "Logical Disk(*)\\% Used Space", "Logical Disk(*)\\Logical Disk Bytes/sec", "Logical Disk(*)\\Disk Read Bytes/sec", "Logical Disk(*)\\Disk Write Bytes/sec", "Logical Disk(*)\\Disk Transfers/sec", "Logical Disk(*)\\Disk Reads/sec", "Logical Disk(*)\\Disk Writes/sec", "Network(*)\\Total Bytes Transmitted", "Network(*)\\Total Bytes Received", "Network(*)\\Total Bytes", "Network(*)\\Total Packets Transmitted", "Network(*)\\Total Packets Received", "Network(*)\\Total Rx Errors", "Network(*)\\Total Tx Errors", "Network(*)\\Total Collisions", "System(*)\\Uptime", "System(*)\\Load1", "System(*)\\Load5", "System(*)\\Load15", "System(*)\\Users", "System(*)\\Unique Users", "System(*)\\CPUs", "Processor\\% Processor Time", "Memory\\Available MBytes", "LogicalDisk(*)\\% Free Space", "LogicalDisk(*)\\Free Megabytes"]
      name                          = "perfCounterDataSource60"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-Perf"]
    }
    syslog {
      facility_names = ["auth", "authpriv", "cron", "daemon", "mark", "kern", "local0"]
      log_levels     = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      name           = "linux-syslogs"
      streams        = ["Microsoft-Syslog"]
    }
  }
}

# 3. Associate the Rule with the Machine (The Bridge)
resource "azurerm_monitor_data_collection_rule_association" "intel_01_assoc" {
  name                    = "intel-01-monitoring-assoc"
  target_resource_id      = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.HybridCompute/machines/mini-me-intel-01"
  data_collection_rule_id = azurerm_monitor_data_collection_rule.sddc_dcr.id
}
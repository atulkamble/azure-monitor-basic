**Basic Azure Monitor Project**. It stands up a Linux VM, wires **Azure Monitor Agent (AMA)** + **Data Collection Rule (DCR)** to **Log Analytics**, adds **workspace-based Application Insights**, enables **Activity Log** diagnostics, and creates a **CPU metric alert** with an **Action Group (email)**.

---

# Basic Azure Monitor on Azure (Terraform)

## What you’ll get

* 🧱 Resource Group + networking (VNet/Subnet/NIC/Public IP/NSG)
* 🖥️ Ubuntu VM (cloud-init installs `stress-ng` for easy load testing)
* 📈 Log Analytics Workspace (LAW)
* 🔎 Application Insights (workspace-based)
* 🧩 Azure Monitor Agent (VM extension) + DCR + Association
* 🛎️ Metric alert: VM **Percentage CPU > 70%** for 5 minutes
* ✉️ Action Group (email receiver)
* 📜 Activity Log → LAW via Diagnostic Setting
* 🔍 Sample KQL queries to verify data

---

## Repo layout

```
azure-monitor-basic/
├─ main.tf
├─ variables.tf
├─ outputs.tf
├─ versions.tf
├─ README.md   <-- (optional notes; content below)
```

---

## `versions.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}
```

## `variables.tf`

```hcl
variable "prefix"        { type = string  default = "amdemo" }
variable "location"      { type = string  default = "eastus" }
variable "admin_username"{ type = string  default = "azureuser" }
variable "ssh_public_key"{ type = string  description = "Your SSH public key" }
variable "alert_email"   { type = string  description = "Email for Action Group alerts" }
```

## `main.tf`

```hcl
provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

locals {
  name     = "${var.prefix}-${random_integer.rand.result}"
  tags     = { project = "azure-monitor-basic", owner = "cloudnautic" }
  vm_size  = "Standard_B2s"
}

# -------------------------
# Resource Group
# -------------------------
resource "azurerm_resource_group" "rg" {
  name     = "${local.name}-rg"
  location = var.location
  tags     = local.tags
}

# -------------------------
# Networking
# -------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "${local.name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "${local.name}-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${local.name}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.tags

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "${local.name}-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
  tags = local.tags
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# -------------------------
# Log Analytics + App Insights
# -------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${local.name}-law"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "appi" {
  name                = "${local.name}-appi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  tags                = local.tags
}

# -------------------------
# Linux VM (Ubuntu) + cloud-init
# -------------------------
locals {
  cloud_init = <<-CLOUD
    #cloud-config
    package_update: true
    packages:
      - stress-ng
    runcmd:
      - echo "Azure Monitor basic demo ready" > /etc/motd
  CLOUD
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${local.name}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = local.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "${local.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(local.cloud_init)
  tags        = local.tags
}

# -------------------------
# Azure Monitor Agent (VM extension)
# -------------------------
resource "azurerm_virtual_machine_extension" "ama" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  settings                   = jsonencode({})
  tags                       = local.tags
}

# -------------------------
# Data Collection Rule (DCR) + Association
# -------------------------
resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                = "${local.name}-dcr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  destinations {
    log_analytics {
      name                  = "toLaw"
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-Syslog"]
    destinations = ["toLaw"]
  }

  data_sources {
    performance_counter {
      name                          = "perfCounters"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes",
        "\\LogicalDisk(_Total)\\Disk Reads/sec",
        "\\LogicalDisk(_Total)\\Disk Writes/sec"
      ]
    }
    syslog {
      name    = "syslogAll"
      streams = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "cron", "daemon", "kern", "local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7", "lpr", "mail", "news", "syslog", "user", "uucp"]
      log_levels     = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency", "Debug"]
    }
  }

  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule_association" "dcr_assoc" {
  name                    = "${local.name}-dcr-assoc"
  target_resource_id      = azurerm_linux_virtual_machine.vm.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
}

# -------------------------
# Activity Log → LAW (subscription-level diagnostic setting)
# -------------------------
resource "azurerm_monitor_diagnostic_setting" "activity" {
  name                       = "${local.name}-activitylogs"
  target_resource_id         = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "Administrative"
  }
  enabled_log {
    category = "Security"
  }
  enabled_log {
    category = "ServiceHealth"
  }
  enabled_log {
    category = "Alert"
  }
  enabled_log {
    category = "Recommendation"
  }
  enabled_log {
    category = "Policy"
  }
  enabled_log {
    category = "Autoscale"
  }
  metric {
    category = "AllMetrics"
  }
}

# -------------------------
# Alerts: Action Group + CPU Metric Alert
# -------------------------
resource "azurerm_monitor_action_group" "ag" {
  name                = "${local.name}-ag"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "am-ag"

  email_receiver {
    name                    = "ops"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  tags = local.tags
}

resource "azurerm_monitor_metric_alert" "vm_cpu_high" {
  name                = "${local.name}-cpu-alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.vm.id]
  description         = "Alert when VM CPU > 70% for 5 minutes"
  severity            = 2
  auto_mitigate       = true
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 70
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}
```

## `outputs.tf`

```hcl
output "resource_group"  { value = azurerm_resource_group.rg.name }
output "workspace_id"    { value = azurerm_log_analytics_workspace.law.id }
output "appinsights_app" { value = azurerm_application_insights.appi.app_id }
output "vm_public_ip"    { value = azurerm_public_ip.pip.ip_address }
```

## `README.md` (quick steps)

````md
# Azure Monitor Basic (Terraform)

## Prereqs
- Azure CLI logged in: `az login`
- Terraform >= 1.6
- One public SSH key in `~/.ssh/id_rsa.pub` (or your key)

## Deploy
```bash
git clone <this-repo> && cd azure-monitor-basic
terraform init

# Option 1: pass variables interactively
terraform apply

# Option 2: provide vars
terraform apply -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)" -var="alert_email=you@example.com" -var="prefix=amdemo" -var="location=eastus"
````

## Connect to VM

```bash
ssh azureuser@$(terraform output -raw vm_public_ip)
```

## Generate CPU load (to trigger alert)

```bash
# On the VM
sudo stress-ng --cpu 2 --timeout 600
```

## Validate in Logs (KQL)

Open **Log Analytics Workspace > Logs** and run:

**Perf (CPU)**

```kusto
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| order by TimeGenerated desc
```

**Syslog**

```kusto
Syslog
| summarize count() by bin(TimeGenerated, 5m), Facility, SeverityLevel, Computer
| order by TimeGenerated desc
```

**Activity Log (routed to LAW)**

```kusto
AzureActivity
| project TimeGenerated, OperationNameValue, ActivityStatusValue, CategoryValue, ResourceGroup, Caller
| order by TimeGenerated desc
```

## Application Insights (workspace-based)

You can use the same LAW queries and also access App Insights features (Transactions/Availability if you later connect an app).

## Cleanup

```bash
terraform destroy
```

````

---

## How to use (quick)
1. **Save files** as shown.
2. Run:
   ```bash
   terraform init
   terraform apply -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)" -var="alert_email=you@example.com"
````

3. SSH to the VM and run `stress-ng` to spike CPU.
4. Watch **Metrics** (VM → Insights), **Logs** (LAW → Logs), and **Alerts** (Monitor → Alerts).
5. Destroy with `terraform destroy` when done.

---

## Optional Azure CLI one-liners (if you need to check things)

```bash
# List alert rules in the RG
az monitor metrics alert list -g $(terraform output -raw resource_group)

# Show LAW tables recently written
az monitor log-analytics query \
  --workspace $(terraform output -raw workspace_id | awk -F/ '{print $NF}') \
  --analytics-query "search * | summarize count() by Type | top 20 by count desc" \
  --out table
```

---

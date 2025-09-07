output "resource_group"  { value = azurerm_resource_group.rg.name }
output "workspace_id"    { value = azurerm_log_analytics_workspace.law.id }
output "appinsights_app" { value = azurerm_application_insights.appi.app_id }
output "vm_public_ip"    { value = azurerm_public_ip.pip.ip_address }

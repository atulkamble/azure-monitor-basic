variable "prefix"        { type = string  default = "amdemo" }
variable "location"      { type = string  default = "eastus" }
variable "admin_username"{ type = string  default = "azureuser" }
variable "ssh_public_key"{ type = string  description = "Your SSH public key" }
variable "alert_email"   { type = string  description = "Email for Action Group alerts" }

variable "prefix"         { type = string  default = "amdemo" }
variable "location"       { type = string  default = "eastus" }
variable "admin_username" { type = string  default = "azureuser" }

# Email where alerts will go
variable "alert_email" {
  type        = string
  description = "Email for Action Group alerts"
}

# --- Keypair options ---
# If true, Terraform generates a keypair and uses it automatically.
variable "generate_key_pair" { type = bool   default = true }

# File name for generated keys under ./keys/
variable "key_name"          { type = string default = "amdemo-key" }

# Optional BYO public key (OpenSSH). Used only when generate_key_pair = false.
variable "ssh_public_key" {
  type        = string
  default     = null
  description = "OpenSSH public key (ssh-rsa/ssh-ed25519 ...). Ignored if generate_key_pair=true."
}

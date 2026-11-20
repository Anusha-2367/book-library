variable "project_name" {
  description = "Short project name used in resource names"
  type        = string
  default     = "booklib"
}

variable "environment" {
  description = "Environment name: dev or prod"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be either dev or prod."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "app_service_sku" {
  description = "App Service Plan SKU (B1 is the cheapest that supports Linux containers reliably)"
  type        = string
  default     = "B1"
}

variable "app_secret_value" {
  description = "Demo secret stored in Key Vault. Pass it using TF_VAR_app_secret_value, never in a file."
  type        = string
  sensitive   = true
}
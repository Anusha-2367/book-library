data "azurerm_client_config" "current" {}

# Random suffix to keep globally-unique names unique
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

locals {
  base_name = "${var.project_name}-${var.environment}"
  suffix    = random_string.suffix.result

  tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.base_name}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------
# Azure Container Registry (no admin user; access via managed identity)
# ---------------------------------------------------------------
resource "azurerm_container_registry" "acr" {
  name                = "acr${var.project_name}${var.environment}${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

# ---------------------------------------------------------------
# Key Vault (RBAC mode)
# ---------------------------------------------------------------
resource "azurerm_key_vault" "kv" {
  name                       = "kv-${var.project_name}-${var.environment}-${local.suffix}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}

# Whoever runs Terraform (you locally, or the pipeline's service principal)
# needs permission to write secrets.
resource "azurerm_role_assignment" "kv_terraform_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role assignments take a short time to propagate in Azure AD
resource "time_sleep" "wait_for_kv_role" {
  depends_on      = [azurerm_role_assignment.kv_terraform_officer]
  create_duration = "60s"
}

resource "azurerm_key_vault_secret" "app_secret" {
  name         = "app-secret"
  value        = var.app_secret_value
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [time_sleep.wait_for_kv_role]
}

# ---------------------------------------------------------------
# App Service Plan + Linux Web App (runs the container from ACR)
# ---------------------------------------------------------------
resource "azurerm_service_plan" "plan" {
  name                = "plan-${local.base_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = local.tags
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-${var.project_name}-${var.environment}-${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true
  tags                = local.tags

  # Managed Identity: lets the app talk to ACR and Key Vault without passwords
  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                               = true
    container_registry_use_managed_identity = true
    health_check_path                       = "/health"

    application_stack {
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
      docker_image_name   = "book-library:latest"
    }
  }

  app_settings = {
    WEBSITES_PORT                       = "8080"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    APP_ENV                             = var.environment
    APP_VERSION                         = "initial"
    # Key Vault reference: App Service fetches the secret using its managed identity
    APP_SECRET = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.app_secret.versionless_id})"
  }

  # The pipeline updates the image and version on every deployment.
  # Tell Terraform not to revert those changes.
  lifecycle {
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name,
      app_settings["APP_VERSION"],
    ]
  }
}

# ---------------------------------------------------------------
# Permissions for the Web App's managed identity
# ---------------------------------------------------------------
resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

resource "azurerm_role_assignment" "app_kv_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}
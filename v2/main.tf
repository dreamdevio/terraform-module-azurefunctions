terraform {
    required_version = ">= 0.12"
}

provider "azurerm" {
    version = "=2.0.0"
    features {}
}

variable "ecosystem_name" {
    type        = string
    description = "Ecosystem name."
}

variable "environment" {
    type        = string
    description = "The environment that this deployment will apply to. Such as DEV, QA, PROD."
}

variable "service_name" {
    type        = string
    description = "Service name."
}

variable "location" {
    type        = string
    description = "Azure location to deploy the resources. Eg.: northeurope, eastus, and etc."
}

variable "extra_function_app_configs" {
    description = "extra_function_app_configs"
}

variable "service_bus_topics" {
    type        = set(string)
    description = "Service bus topic to publish service aggregate domain events."
}

variable "service_bus_subscriptions" {
    description = "Key pair of Service bus topics to create a subscription."
}

locals {
    ecosystem_rg_name    = "rg-${var.ecosystem_name}-${var.environment}"
    ecosystem_sb_name    = "sb-${var.ecosystem_name}-${var.environment}"

    default_tags = {
        Env           = var.environment
        EcosystemName = var.ecosystem_name
        ServiceName   = var.service_name
    }
}

resource "azurerm_resource_group" "rg" {
    name     = "rg-${var.service_name}-${var.environment}"
    location = var.location

    tags = local.default_tags
}

resource "azurerm_storage_account" "st" {
    name                     = "stfunc${substr(var.service_name, 0, 14)}${var.environment}"
    resource_group_name      = azurerm_resource_group.rg.name
    location                 = azurerm_resource_group.rg.location
    account_tier             = "Standard"
    account_replication_type = "LRS"

    tags = local.default_tags
}

resource "azurerm_app_service_plan" "plan" {
    name                = "plan-${var.service_name}-${var.environment}"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    kind                = "FunctionApp"

    sku {
        tier = "Dynamic"
        size = "Y1"
    }

    tags = local.default_tags
}

resource "azurerm_function_app" "func" {
    name                      = "func-${var.service_name}-${var.environment}"
    location                  = azurerm_resource_group.rg.location
    resource_group_name       = azurerm_resource_group.rg.name
    app_service_plan_id       = azurerm_app_service_plan.plan.id
    storage_connection_string = azurerm_storage_account.st.primary_connection_string
    version = "~3"

    auth.settings = var.extra_function_app_configs.auth_settings

    tags = local.default_tags
}

resource "azurerm_servicebus_topic" "topic" {
    for_each = var.service_bus_topics
        name                = "sbt-${each.value}"
        resource_group_name = local.ecosystem_rg_name
        namespace_name      = local.ecosystem_sb_name

        enable_partitioning = false
}

resource "azurerm_servicebus_subscription" "subscription" {
    for_each = var.service_bus_subscriptions
        name                = each.value
        resource_group_name = local.ecosystem_rg_name
        namespace_name      = local.ecosystem_sb_name
        topic_name          = "sbt-${each.key}"
        max_delivery_count  = 1
}

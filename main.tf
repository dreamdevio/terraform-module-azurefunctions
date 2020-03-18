terraform {
    required_version = ">= 0.12"
}

variable "solution_name" {
    type        = string
    description = "Solution name."
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

variable "service_bus_topic" {
    type        = string
    description = "Service bus topic to publish service aggregate domain events."
}

variable "service_bus_subscriptions" {
}

locals {
    solution_rg_name    = "rg-${var.solution_name}-${var.environment}"
    solution_sb_name    = "sb-${var.solution_name}-${var.environment}"
    default_tags        = {
        environment = var.environment
        solution    = var.solution_name
    }
}

provider "azurerm" {
    version = "1.36.0"
}

resource "azurerm_resource_group" "rg" {
    name     = "rg-${var.resource_group_name}-${var.environment}"
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
    
    tags = local.default_tags
}

resource "azurerm_servicebus_topic" "topic" {
    name                = "sbt-${var.service_bus_topic}"
    resource_group_name = local.solution_rg_name
    namespace_name      = local.solution_sb_name

    enable_partitioning = false
}

resource "azurerm_servicebus_subscription" "subscription" {
    for_each = var.service_bus_subscriptions
        name                = each.value
        resource_group_name = local.solution_rg_name
        namespace_name      = local.solution_sb_name
        topic_name          = "sbt-${each.key}"
        max_delivery_count  = 1
}

terraform {
    required_version = ">= 0.12"
    backend "azurerm" {
        
    }
}

variable "resource_group_name" {
  description = "The name of the resource group for the microservice"
}

variable "subscription_id" {
  description = "The azure subscription id"
}

provider "azurerm" {
    version         = "1.36.0"
    subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "rg" {
    name     = var.resource_group_name
    location = "northeurope"
}

resource "azurerm_storage_account" "sa" {
    name                     = "${replace(var.resource_group_name, ".", "")}sa"
    resource_group_name      = azurerm_resource_group.rg.name
    location                 = azurerm_resource_group.rg.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "asp" {
    name                = "${replace(var.resource_group_name, ".", "-")}sa"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    kind                = "FunctionApp"

    sku {
        tier = "Dynamic"
        size = "Y1"
    }
}

resource "azurerm_function_app" "fa" {
    name                      = "${replace(var.resource_group_name, ".", "-")}app"
    location                  = azurerm_resource_group.rg.location
    resource_group_name       = azurerm_resource_group.rg.name
    app_service_plan_id       = azurerm_app_service_plan.asp.id
    storage_connection_string = azurerm_storage_account.sa.primary_connection_string
}
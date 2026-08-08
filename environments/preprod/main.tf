module "resource_group" {
  source = "../../modules/azurerm_resource_group"
  rgs    = var.rgs
}

module "virtual_network" {
  depends_on = [module.resource_group]
  source     = "../../modules/azurerm_virtual_network"
  vnets      = var.vnets
}

module "subnets" {
  depends_on = [module.virtual_network]
  source     = "../../modules/azurerm_subnet"
  subnets    = var.subnets
}

module "public_ip" {
  depends_on = [module.resource_group]
  source     = "../../modules/azurerm_public_ip"
  public_ips = var.public_ips
}

module "key_vault" {
  depends_on = [module.resource_group]
  source     = "../../modules/azurerm_key_vault"
  key_vaults = var.key_vaults
}

module "virtual_machines" {
  depends_on = [module.subnets, module.key_vault]
  source     = "../../modules/azurerm_virtual_machine"
  vms        = var.vms
}

module "bastion" {
  depends_on = [module.subnets, module.public_ip]
  source     = "../../modules/azurerm_bastion"
  bastions   = var.bastions
}

module "application_gateway" {
  depends_on   = [module.subnets, module.public_ip, module.virtual_machines]
  source       = "../../modules/azurerm_application_gateway"
  app_gateways = var.app_gateways
}

module "load_balancer" {
  depends_on     = [module.subnets, module.virtual_machines]
  source         = "../../modules/azurerm_load_balancer"
  load_balancers = var.load_balancers
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "appgw_assoc" {
  for_each                = { for k, v in var.vms : k => v if startswith(k, "frontend") }
  network_interface_id    = module.virtual_machines.nic_ids[each.key]
  ip_configuration_name   = module.virtual_machines.nic_ip_configurations[each.key]
  backend_address_pool_id = module.application_gateway.backend_address_pool_ids["appgw1"]
}

resource "azurerm_network_interface_backend_address_pool_association" "lb_assoc" {
  for_each                = { for k, v in var.vms : k => v if startswith(k, "backend") }
  network_interface_id    = module.virtual_machines.nic_ids[each.key]
  ip_configuration_name   = module.virtual_machines.nic_ip_configurations[each.key]
  backend_address_pool_id = module.load_balancer.backend_address_pool_ids["lb1"]
}


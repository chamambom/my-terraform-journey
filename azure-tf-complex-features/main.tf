####################################################################################
#              Resource Group Module is Used to Create Resource Groups            
####################################################################################
module "workload-a-resourcegroup" {
  source = "./modules/resourcegroups"
  # Resource Group Variables
  rg_name     = "rg-workload-a-prd-ae-001"
  rg_location = "australiaeast"
  
  # providers = {
  #   azurerm = azurerm.prod
  # }
}


module "workload-b-resourcegroup" {
  source = "./modules/azurerm-resourcegroup"
  # Resource Group Variables
  rg_name     = "rg-workload-b-prd-ae-001"
  rg_location = "australiaeast"
  
  # providers = {
  #   azurerm = azurerm.prod
  # }
}

####################################################################################
#              virtual network Module is Used to vnets and subnets            
####################################################################################

module "hub-vnet" {
  source = "./modules/azurerm-network-resources"


  resource_group_name            = "rg-shared-ae-01"
  vnetwork_name                  = "vnet-shared-hub-ae-001"
  location                       = "australiaeast"
  vnet_address_space             = ["10.1.0.0/16"]
  firewall_subnet_address_prefix = ["10.1.0.0/26"]
  gateway_subnet_address_prefix  = ["10.1.1.0/27"]
  create_network_watcher         = false

  # Adding Standard DDoS Plan, and custom DNS servers (Optional)
  create_ddos_plan = false

  # Multiple Subnets, Service delegation, Service Endpoints, Network security groups
  # These are default subnets with required configuration, check README.md for more details
  # NSG association to be added automatically for all subnets listed here.
  # First two address ranges from VNet Address space reserved for Gateway And Firewall Subnets.
  # ex.: For 10.1.0.0/16 address space, usable address range start from 10.1.2.0/24 for all subnets.
  # subnet name will be set as per Azure naming convention by defaut. expected value here is: <App or project name>
  subnets = {
    mgnt_subnet = {
      subnet_name           = "snet-management"
      subnet_address_prefix = ["10.1.2.0/24"]

      delegation = {
        name = "testdelegation"
        service_delegation = {
          name    = "Microsoft.ContainerInstance/containerGroups"
          actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
        }
      }

      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["weballow", "100", "Inbound", "Allow", "Tcp", "80", "*", "0.0.0.0/0"],
        ["weballow1", "101", "Inbound", "Allow", "", "443", "*", ""],
        ["weballow2", "102", "Inbound", "Allow", "Tcp", "8080-8090", "*", ""],
      ]

      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["ntp_out", "103", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"],
      ]
    }

    dmz_subnet = {
      subnet_name           = "snet-appgateway"
      subnet_address_prefix = ["10.1.3.0/24"]
      service_endpoints     = ["Microsoft.Storage"]

      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["weballow", "200", "Inbound", "Allow", "Tcp", "80", "*", ""],
        ["weballow1", "201", "Inbound", "Allow", "Tcp", "443", "AzureLoadBalancer", ""],
        ["weballow2", "202", "Inbound", "Allow", "Tcp", "9090", "VirtualNetwork", ""],
      ]

      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
      ]
    }

    pvt_subnet = {
      subnet_name           = "snet-pvt"
      subnet_address_prefix = ["10.1.4.0/24"]
      service_endpoints     = ["Microsoft.Storage"]
    }
  }

  # Adding TAG's to your Azure resources (Required)
  tags = {
    ProjectName  = "demo-internal"
    Env          = "dev"
    Owner        = "user@example.com"
    BusinessUnit = "CORP"
    ServiceClass = "Gold"
  }
}



####################################################################################
#              Route table Module is Used to route tables            
####################################################################################


module "route-table-workload-a" {
  source              = "./modules/azurerm-route-table"
  name                = "rt-workload-a-afwroute-001"
  resource_group_name = module.workload-a-resourcegroup.rg_name
  location            = "australiaeast"
  routes = [
    { name = "ToFortigateFirewall", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.50.0.68" }
  ]
  disable_bgp_route_propagation = true

  subnet_ids = [data.azurerm_subnet.print.id]

  #   providers = {
  #   azurerm = azurerm.prod
  # }
}


module "route-table-workload-b" {
  source              = "./modules/azurerm-route-table"
  name                = "rt-workload-b-afwroute-001"
  resource_group_name = module.workload-b-resourcegroup.rg_name
  location            = "australiaeast"
  routes = [
    { name = "ToFortigateFirewall", address_prefix = "10.0.0.0/8", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.50.0.68" },
    { name = "WANA", address_prefix = "59.153.21.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.50.0.68" },
    { name = "WANB", address_prefix = "202.49.24.0/23", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.50.0.68" },
    { name = "WANC", address_prefix = "202.49.26.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.50.0.68" }
  ]
  disable_bgp_route_propagation = true

  subnet_ids = [data.azurerm_subnet.aadds.id, data.azurerm_subnet.pdns-resolver-inbound.id, data.azurerm_subnet.pdns-resolver-outbound.id ]

  #   providers = {
  #   azurerm = azurerm.shared
  # }
}
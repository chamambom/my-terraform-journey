####################################################################################
#              Resource Group Module is Used to Create Resource Groups            
####################################################################################
module "workload-a-resourcegroup" {
  source = "./modules/azure-resourcegroup"
  # Resource Group Variables
  rg_name     = "rg-workload-a-prd-ae-001"
  rg_location = "australiaeast"

  # providers = {
  #   azurerm = azurerm.prod
  # }
}


module "workload-b-resourcegroup" {
  source = "./modules/azure-resourcegroup"
  # Resource Group Variables
  rg_name     = "rg-workload-b-prd-ae-001"
  rg_location = "australiaeast"

  # providers = {
  #   azurerm = azurerm.prod
  # }
}

module "connectivity-resourcegroup" {
  source = "./modules/azure-resourcegroup"
  # Resource Group Variables
  rg_name     = "rg-shared-ae-001"
  rg_location = "australiaeast"

  # providers = {
  #   azurerm = azurerm.prod
  # }
}

####################################################################################
#              virtual network Module is Used to vnets and subnets            
####################################################################################

module "hub-vnet" {
  source = "./modules/azure-vnet-resources"


  resource_group_name = module.connectivity-resourcegroup.rg_name
  vnetwork_name       = "vnet-connectivity-hub-ae-001"
  location            = "australiaeast"
  vnet_address_space  = ["10.210.0.0/24"]


  firewall_subnet_address_prefix = ["10.210.0.0/26"]
  gateway_subnet_address_prefix  = ["10.210.0.64/26"]
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
      subnet_address_prefix = ["10.210.0.128/27"]

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
      subnet_address_prefix = ["10.210.0.160/27"]
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
      subnet_address_prefix = ["10.210.0.192/27"]
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

module "spoke1-vnet" {
  source = "./modules/azure-vnet-resources"

  resource_group_name = module.workload-a-resourcegroup.rg_name
  vnetwork_name       = "vnet-spoke1-ae-001"
  location            = "australiaeast"
  vnet_address_space  = ["10.220.0.0/24"]

  # firewall_subnet_address_prefix = ["10.220.0.96/27"]
  # gateway_subnet_address_prefix  = ["10.220.0.0/26"]
  create_network_watcher = false

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
      subnet_address_prefix = ["10.220.0.96/27"]

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
      subnet_address_prefix = ["10.220.0.64/27"]
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
      subnet_address_prefix = ["10.220.0.128/27"]
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



module "spoke2-vnet" {
  source = "./modules/azure-vnet-resources"

  resource_group_name = module.workload-b-resourcegroup.rg_name
  vnetwork_name       = "vnet-spoke2-ae-001"
  location            = "australiaeast"
  vnet_address_space  = ["10.230.0.0/24"]

  create_network_watcher = false

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
      subnet_address_prefix = ["10.230.0.128/27"]

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
      subnet_address_prefix = ["10.230.0.64/27"]
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
      subnet_address_prefix = ["10.230.0.96/27"]
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
  source              = "./modules/azure-route-table"
  name                = "rt-workload-a-afwroute-001"
  resource_group_name = module.workload-a-resourcegroup.rg_name
  location            = "australiaeast"
  routes = [
    { name = "ToFortigateFirewall", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.50.0.68" }
  ]
  disable_bgp_route_propagation = true

  subnet_ids = module.spoke1-vnet.subnet_ids

  depends_on = [module.hub-vnet, module.spoke1-vnet, module.spoke2-vnet]

  #   providers = {
  #   azurerm = azurerm.prod
  # }

}


module "route-table-workload-b" {
  source              = "./modules/azure-route-table"
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

  subnet_ids = module.spoke2-vnet.subnet_ids

  depends_on = [module.hub-vnet, module.spoke1-vnet, module.spoke2-vnet]


  #   providers = {
  #   azurerm = azurerm.shared
  # }
}

####################################################################################
#              Spokes Module is Used to route tables            
####################################################################################

# vnet-peering Module is used to create peering between Virtual Networks
module "hub-to-spoke1" {
  source = "./modules/azure-vnet-peering"


  virtual_network_peering_name = "vnet-hub-to-vnet-workload-a"
  resource_group_name          = module.connectivity-resourcegroup.rg_name
  virtual_network_name         = module.hub-vnet.virtual_network_name
  remote_virtual_network_id    = module.spoke1-vnet.virtual_network_id
  allow_virtual_network_access = "true"
  allow_forwarded_traffic      = "true"
  allow_gateway_transit        = "true"
  use_remote_gateways          = "false"

  # providers = {
  #   azurerm = azurerm.connectivity
  # }

}

# vnet-peering Module is used to create peering between Virtual Networks
module "spoke1-to-hub" {
  source = "./modules/azure-vnet-peering"

  virtual_network_peering_name = "vnet-workload-a-to-vnet-hub"
  resource_group_name          = module.workload-a-resourcegroup.rg_name
  virtual_network_name         = module.spoke1-vnet.virtual_network_name
  remote_virtual_network_id    = module.hub-vnet.virtual_network_id
  allow_virtual_network_access = "true"
  allow_forwarded_traffic      = "true"
  allow_gateway_transit        = "false"
  # As there is no gateway while testing - Setting to False
  #use_remote_gateways   = "true"
  use_remote_gateways = "false"


  # providers = {
  #   azurerm = azurerm.prod
  # }

}


# azurefirewall Module is used to create Azure Firewall 
# Firewall Policy
# Associate Firewall Policy with Azure Firewall
# Network and Application Firewall Rules 
module "azure_firewall_01" {
  source     = "./modules/azure-firewall"

  depends_on = [module.hub-vnet]

  azure_firewall_name = "afw-connectivity-hub-01"
  location            = module.hub-resourcegroup.rg_location
  resource_group_name = module.hub-resourcegroup.rg_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ipconfig_name        = "configuration"
  subnet_id            = module.hub-vnet.vnet_subnet_id[2]
  public_ip_address_id = module.public_ip_03.public_ip_address_id
  
  azure_firewall_policy_name            = "afwpolicy-tpk-ae-001"
  
}


# NB - I deployed this code with the hope that I will make it better
# If you become the custodian of this codebase, you need to enhance the code by using dynamic blocks for rules to
# avoid repition of the code blocks


# Resource Group Module is Used to Create Resource Groups
module "ipgroups-resourcegroup" {
  source = "./modules/resourcegroups"
  # Resource Group Variables
  az_rg_name     = "rg-ipgroups-001"
  az_rg_location = "australiaeast"
  providers = {
    azurerm = azurerm.connectivity
  }
}

module "ip_groupA" {
  source = "./modules/ipgroups"

  ip_group_name = "NPS_Radius_Servers"
  resource_group_name = module.ipgroups-resourcegroup.rg_name
  location = "australiaeast"
  cidr_blocks =  ["10.210.6.0/28"]

  providers = {
    azurerm = azurerm.connectivity
  }
}

module "ip_groupB" {
  source = "./modules/ipgroups"

  ip_group_name = "AOVPN_Internal_Subnet"
  resource_group_name = module.ipgroups-resourcegroup.rg_name
  location = "australiaeast"
  cidr_blocks =  ["10.210.4.0/27"]

  providers = {
    azurerm = azurerm.connectivity
  }
}

module "ip_groupC" {
  source = "./modules/ipgroups"

  ip_group_name = "AD_Servers"
  resource_group_name = module.ipgroups-resourcegroup.rg_name
  location = "australiaeast"
  cidr_blocks =  ["10.210.6.0/28"]

  providers = {
    azurerm = azurerm.connectivity
  }
}


module "azure_firewall_rules" {
  source     = "./modules/firewallrules"
  location            = "australiaeast"
  resource_group_name = module.ipgroups-resourcegroup.rg_name

  azure_firewall_policy_coll_group_name = "afwpolicy-collection-group-tpk-ae-001"
  azure_firewall_policy_name            = "afwpolicy-tpk-ae-001"
  priority                              = 100

  network_rule_coll_name_01     = "Blocked_Network_Rules"
  network_rule_coll_priority_01 = "200"
  network_rule_coll_action_01   = "Deny"
  network_rules_01 = [
    {
      name                  = "Blocked_rule_1"
      source_ip_groups       = [module.ip_groupA.ip_group_id_out]
      destination_ip_groups  = [module.ip_groupB.ip_group_id_out]
      destination_ports     = [11]
      protocols             = ["TCP"]
    },

  ]

  network_rule_coll_name_02     = "Allowed_Network_Rules"
  network_rule_coll_priority_02 = "300"
  network_rule_coll_action_02   = "Allow"
  network_rules_02 = [
    {
      name                  = "NPS_Radius_Servers_Outbound"
      source_ip_groups       = [module.ip_groupA.ip_group_id_out]
      destination_ip_groups  = [module.ip_groupB.ip_group_id_out]
      destination_ports     = [1812,1813,1645,1646]
      protocols             = ["UDP","ICMP"]
    },
     {
      name                  = "NPS_Radius_Servers_Inbound"
      source_ip_groups       = [module.ip_groupB.ip_group_id_out]
      destination_ip_groups  = [module.ip_groupA.ip_group_id_out]
      destination_ports     = [1812,1813,1645,1646]
      protocols             = ["UDP","ICMP"]
    },
    {
      name                  = "AD_Servers_Inbound"
      source_ip_groups       = [module.ip_groupB.ip_group_id_out]
      destination_ip_groups  = [module.ip_groupC.ip_group_id_out]
      destination_ports     = [389,636,445,53,3268,3269,88,135,464,139,"49152-65535",88]
      protocols             = ["UDP","TCP","ICMP"]
    },

    {
      name                  = "AD_Servers_Outbound"
      source_ip_groups       = [module.ip_groupC.ip_group_id_out]
      destination_ip_groups  = [module.ip_groupB.ip_group_id_out]
      destination_ports     = [389,636,445,53,3268,3269,88,135,464,139,"49152-65535",88]
      protocols             = ["UDP","TCP","ICMP"]
    },

  ]
  


  application_rule_coll_name     = "Allowed_Services"
  application_rule_coll_priority = "500"
  application_rule_coll_action   = "Allow"
  application_rules = [
    {
      name              = "Allowed_website_01"
      source_addresses  = ["*"]
      destination_fqdns = ["bing.co.uk"]
    },
    {
      name              = "Allowed_website_02"
      source_addresses  = ["*"]
      destination_fqdns = ["*.bing.com"]
    }
  ]
  application_protocols = [
    {
      type = "Http"
      port = 80
    },
    {
      type = "Https"
      port = 443
    }
  ]

  providers = {
    azurerm = azurerm.connectivity
  }

}
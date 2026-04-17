
# =============================================================================
# Azure Virtual WAN - Complete Infrastructure
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# =============================================================================
# Resource Group
# =============================================================================

resource "azurerm_resource_group" "vwan_rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# =============================================================================
# Virtual WAN
# =============================================================================

resource "azurerm_virtual_wan" "vwan" {
  name                = var.vwan_name
  resource_group_name = azurerm_resource_group.vwan_rg.name
  location            = azurerm_resource_group.vwan_rg.location

  type                              = var.vwan_type # "Standard" or "Basic"
  allow_branch_to_branch_traffic    = true
  disable_vpn_encryption            = false
  office365_local_breakout_category = "None"

  tags = var.tags
}

# =============================================================================
# Virtual Hub (one per region)
# =============================================================================

resource "azurerm_virtual_hub" "hub" {
  for_each = var.virtual_hubs

  name                = each.value.name
  resource_group_name = azurerm_resource_group.vwan_rg.name
  location            = each.value.location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = each.value.address_prefix
  sku                 = var.vwan_type # Must match vWAN type

  tags = var.tags
}

# =============================================================================
# VPN Gateway (Site-to-Site) — one per hub
# =============================================================================

resource "azurerm_vpn_gateway" "vpn_gw" {
  for_each = { for k, v in var.virtual_hubs : k => v if v.deploy_vpn_gateway }

  name                = "${each.value.name}-vpngw"
  resource_group_name = azurerm_resource_group.vwan_rg.name
  location            = each.value.location
  virtual_hub_id      = azurerm_virtual_hub.hub[each.key].id
  scale_unit          = each.value.vpn_scale_unit

  bgp_settings {
    asn         = each.value.vpn_bgp_asn
    peer_weight = 0
  }

  tags = var.tags
}

# =============================================================================
# VPN Site (Branch / On-Premises)
# =============================================================================

resource "azurerm_vpn_site" "vpn_site" {
  for_each = var.vpn_sites

  name                = each.value.name
  resource_group_name = azurerm_resource_group.vwan_rg.name
  location            = azurerm_resource_group.vwan_rg.location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id

  address_cidrs = each.value.address_cidrs

  link {
    name       = "${each.value.name}-link1"
    ip_address = each.value.link_ip_address
    speed_in_mbps = each.value.link_speed_mbps

    bgp {
      asn             = each.value.bgp_asn
      peering_address = each.value.bgp_peering_address
    }
  }

  tags = var.tags
}

# =============================================================================
# VPN Gateway Connection (Hub → VPN Site)
# =============================================================================

resource "azurerm_vpn_gateway_connection" "vpn_conn" {
  for_each = var.vpn_sites

  name               = "${each.value.name}-conn"
  vpn_gateway_id     = azurerm_vpn_gateway.vpn_gw[each.value.hub_key].id
  remote_vpn_site_id = azurerm_vpn_site.vpn_site[each.key].id

  vpn_link {
    name             = "${each.value.name}-link1"
    vpn_site_link_id = azurerm_vpn_site.vpn_site[each.key].link[0].id
    shared_key       = each.value.shared_key

    protocol             = "IKEv2"
    bandwidth_mbps       = each.value.link_speed_mbps
    bgp_enabled          = true
    ratelimit_enabled    = false
    route_weight         = 0

    ipsec_policy {
      dh_group                 = "DHGroup14"
      ike_encryption_algorithm = "AES256"
      ike_integrity_algorithm  = "SHA256"
      encryption_algorithm     = "AES256"
      integrity_algorithm      = "SHA256"
      pfs_group                = "PFS14"
      sa_data_size_kb          = 102400000
      sa_lifetime_sec          = 3600
    }
  }
}

# =============================================================================
# ExpressRoute Gateway — one per hub (optional)
# =============================================================================

resource "azurerm_express_route_gateway" "er_gw" {
  for_each = { for k, v in var.virtual_hubs : k => v if v.deploy_er_gateway }

  name                = "${each.value.name}-ergw"
  resource_group_name = azurerm_resource_group.vwan_rg.name
  location            = each.value.location
  virtual_hub_id      = azurerm_virtual_hub.hub[each.key].id
  scale_units         = each.value.er_scale_unit

  tags = var.tags
}

# =============================================================================
# Point-to-Site VPN Gateway
# =============================================================================

resource "azurerm_point_to_site_vpn_gateway" "p2s_gw" {
  for_each = { for k, v in var.virtual_hubs : k => v if v.deploy_p2s_gateway }

  name                        = "${each.value.name}-p2sgw"
  resource_group_name         = azurerm_resource_group.vwan_rg.name
  location                    = each.value.location
  virtual_hub_id              = azurerm_virtual_hub.hub[each.key].id
  scale_unit                  = each.value.p2s_scale_unit
  vpn_server_configuration_id = azurerm_vpn_server_configuration.p2s_config[each.key].id

  connection_configuration {
    name = "p2s-connection-config"

    vpn_client_address_pool {
      address_prefixes = each.value.p2s_client_address_pool
    }
  }

  tags = var.tags
}

resource "azurerm_vpn_server_configuration" "p2s_config" {
  for_each = { for k, v in var.virtual_hubs : k => v if v.deploy_p2s_gateway }

  name                     = "${each.value.name}-p2s-vpnconfig"
  resource_group_name      = azurerm_resource_group.vwan_rg.name
  location                 = each.value.location
  vpn_authentication_types = ["Certificate"]

  client_root_certificate {
    name             = "DigiCert-Federated-ID-Root-CA"
    public_cert_data = var.p2s_root_certificate_public_data
  }

  tags = var.tags
}

# =============================================================================
# Azure Firewall (Secured Hub) — optional
# =============================================================================

resource "azurerm_firewall" "hub_firewall" {
  for_each = { for k, v in var.virtual_hubs : k => v if v.deploy_firewall }

  name                = "${each.value.name}-fw"
  resource_group_name = azurerm_resource_group.vwan_rg.name
  location            = each.value.location
  sku_name            = "AZFW_Hub"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.fw_policy[each.key].id

  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.hub[each.key].id
    public_ip_count = 1
  }

  tags = var.tags
}

resource "azurerm_firewall_policy" "fw_policy" {
  for_each = { for k, v in var.virtual_hubs : k => v if v.deploy_firewall }

  name                = "${each.value.name}-fwpolicy"
  resource_group_name = azurerm_resource_group.vwan_rg.name
  location            = each.value.location
  sku                 = "Standard"

  dns {
    proxy_enabled = true
  }

  tags = var.tags
}

# Firewall Policy Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "fw_rules" {
  for_each           = { for k, v in var.virtual_hubs : k => v if v.deploy_firewall }
  name               = "${each.value.name}-fwrules"
  firewall_policy_id = azurerm_firewall_policy.fw_policy[each.key].id
  priority           = 100

  network_rule_collection {
    name     = "allow-internal"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-rfc1918"
      protocols             = ["Any"]
      source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_addresses = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_ports     = ["*"]
    }
  }

  application_rule_collection {
    name     = "allow-web"
    priority = 200
    action   = "Allow"

    rule {
      name              = "allow-microsoft-updates"
      source_addresses  = ["*"]
      destination_fqdns = ["*.microsoft.com", "*.windowsupdate.com"]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

# =============================================================================
# Hub Route Table (custom routing)
# =============================================================================

resource "azurerm_virtual_hub_route_table" "custom_rt" {
  for_each       = { for k, v in var.virtual_hubs : k => v if v.create_custom_route_table }
  name           = "${each.value.name}-custom-rt"
  virtual_hub_id = azurerm_virtual_hub.hub[each.key].id
  labels         = ["custom"]

  route {
    name              = "to-shared-services"
    destinations_type = "CIDR"
    destinations      = ["10.0.0.0/8"]
    next_hop_type     = "ResourceId"
    next_hop          = azurerm_firewall.hub_firewall[each.key].id
  }
}

# =============================================================================
# Hub Virtual Network Connection (Spoke VNets → Hub)
# =============================================================================

resource "azurerm_virtual_network" "spoke_vnet" {
  for_each = var.spoke_vnets

  name                = each.value.name
  resource_group_name = azurerm_resource_group.vwan_rg.name
  location            = each.value.location
  address_space       = each.value.address_space

  tags = var.tags
}

resource "azurerm_subnet" "spoke_subnet" {
  for_each = var.spoke_vnets

  name                 = "default"
  resource_group_name  = azurerm_resource_group.vwan_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet[each.key].name
  address_prefixes     = each.value.subnet_prefixes
}

resource "azurerm_virtual_hub_connection" "spoke_connection" {
  for_each = var.spoke_vnets

  name                      = "${each.value.name}-conn"
  virtual_hub_id            = azurerm_virtual_hub.hub[each.value.hub_key].id
  remote_virtual_network_id = azurerm_virtual_network.spoke_vnet[each.key].id

  internet_security_enabled = each.value.internet_security_enabled

  routing {
    associated_route_table_id = azurerm_virtual_hub.hub[each.value.hub_key].default_route_table_id

    propagated_route_table {
      labels          = ["default"]
      route_table_ids = [azurerm_virtual_hub.hub[each.value.hub_key].default_route_table_id]
    }
  }
}

# =============================================================================
# Log Analytics Workspace (Diagnostics)
# =============================================================================

resource "azurerm_log_analytics_workspace" "vwan_logs" {
  name                = "${var.vwan_name}-logs"
  resource_group_name = azurerm_resource_group.vwan_rg.name
  location            = azurerm_resource_group.vwan_rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# =============================================================================
# Diagnostic Settings — vWAN & Firewall
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "fw_diag" {
  for_each = { for k, v in var.virtual_hubs : k => v if v.deploy_firewall }

  name                       = "${each.value.name}-fw-diag"
  target_resource_id         = azurerm_firewall.hub_firewall[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vwan_logs.id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }
  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

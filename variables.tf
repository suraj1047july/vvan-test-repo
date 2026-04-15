# =============================================================================
# Variables — Azure Virtual WAN
# =============================================================================

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "Primary Azure region for the resource group"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-vwan-prod"
}

variable "vwan_name" {
  description = "Name of the Virtual WAN"
  type        = string
  default     = "vwan-prod"
}

variable "vwan_type" {
  description = "Virtual WAN type: Standard or Basic"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Basic"], var.vwan_type)
    error_message = "vwan_type must be either 'Standard' or 'Basic'."
  }
}

# =============================================================================
# Virtual Hubs
# =============================================================================

variable "virtual_hubs" {
  description = "Map of Virtual Hubs to deploy"
  type = map(object({
    name           = string
    location       = string
    address_prefix = string

    # Gateway toggles
    deploy_vpn_gateway = bool
    vpn_scale_unit     = optional(number, 1)
    vpn_bgp_asn        = optional(number, 65515)

    deploy_er_gateway = bool
    er_scale_unit     = optional(number, 1)

    deploy_p2s_gateway       = bool
    p2s_scale_unit           = optional(number, 1)
    p2s_client_address_pool  = optional(list(string), ["172.16.0.0/24"])

    # Firewall toggle
    deploy_firewall = bool

    # Custom route table toggle
    create_custom_route_table = bool
  }))

  default = {
    hub_eastus = {
      name           = "vhub-eastus"
      location       = "eastus"
      address_prefix = "10.100.0.0/23"

      deploy_vpn_gateway = true
      vpn_scale_unit     = 1
      vpn_bgp_asn        = 65515

      deploy_er_gateway = false
      er_scale_unit     = 1

      deploy_p2s_gateway      = false
      p2s_scale_unit          = 1
      p2s_client_address_pool = ["172.16.0.0/24"]

      deploy_firewall           = true
      create_custom_route_table = true
    }

    hub_westeurope = {
      name           = "vhub-westeurope"
      location       = "westeurope"
      address_prefix = "10.101.0.0/23"

      deploy_vpn_gateway = true
      vpn_scale_unit     = 1
      vpn_bgp_asn        = 65515

      deploy_er_gateway = false
      er_scale_unit     = 1

      deploy_p2s_gateway      = false
      p2s_scale_unit          = 1
      p2s_client_address_pool = ["172.16.1.0/24"]

      deploy_firewall           = true
      create_custom_route_table = true
    }
  }
}

# =============================================================================
# VPN Sites (Branch / On-Premises)
# =============================================================================

variable "vpn_sites" {
  description = "Map of on-premises/branch VPN sites to connect"
  type = map(object({
    name                 = string
    hub_key              = string
    address_cidrs        = list(string)
    link_ip_address      = string
    link_speed_mbps      = number
    bgp_asn              = number
    bgp_peering_address  = string
    shared_key           = string
  }))
  default = {}
  # Example:
  # branch_office_london = {
  #   name                = "vpnsite-london"
  #   hub_key             = "hub_westeurope"
  #   address_cidrs       = ["192.168.1.0/24"]
  #   link_ip_address     = "203.0.113.10"
  #   link_speed_mbps     = 100
  #   bgp_asn             = 65001
  #   bgp_peering_address = "169.254.21.1"
  #   shared_key          = "SuperSecretKey123!"
  # }
}

# =============================================================================
# Spoke VNets
# =============================================================================

variable "spoke_vnets" {
  description = "Map of spoke Virtual Networks to connect to hubs"
  type = map(object({
    name                      = string
    location                  = string
    hub_key                   = string
    address_space             = list(string)
    subnet_prefixes           = list(string)
    internet_security_enabled = bool
  }))

  default = {
    spoke_app = {
      name                      = "vnet-spoke-app"
      location                  = "eastus"
      hub_key                   = "hub_eastus"
      address_space             = ["10.10.0.0/16"]
      subnet_prefixes           = ["10.10.1.0/24"]
      internet_security_enabled = true
    }
    spoke_data = {
      name                      = "vnet-spoke-data"
      location                  = "eastus"
      hub_key                   = "hub_eastus"
      address_space             = ["10.20.0.0/16"]
      subnet_prefixes           = ["10.20.1.0/24"]
      internet_security_enabled = true
    }
    spoke_shared_eu = {
      name                      = "vnet-spoke-shared-eu"
      location                  = "westeurope"
      hub_key                   = "hub_westeurope"
      address_space             = ["10.30.0.0/16"]
      subnet_prefixes           = ["10.30.1.0/24"]
      internet_security_enabled = true
    }
  }
}

# =============================================================================
# P2S Certificate
# =============================================================================

variable "p2s_root_certificate_public_data" {
  description = "Base64-encoded public certificate data for P2S VPN (root CA)"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    environment = "production"
    managed_by  = "terraform"
    project     = "networking"
  }
}

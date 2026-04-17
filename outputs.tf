# =============================================================================
# # Outputs — Azure Virtual WAN
# # =============================================================================

# output "virtual_wan_id" {
#   description = "Resource ID of the Virtual WAN"
#   value       = azurerm_virtual_wan.vwan.id
# }

# output "virtual_wan_name" {
#   description = "Name of the Virtual WAN"
#   value       = azurerm_virtual_wan.vwan.name
# }

# output "virtual_hub_ids" {
#   description = "Resource IDs of all Virtual Hubs"
#   value       = { for k, v in azurerm_virtual_hub.hub : k => v.id }
# }

# output "virtual_hub_addresses" {
#   description = "Address prefixes of all Virtual Hubs"
#   value       = { for k, v in azurerm_virtual_hub.hub : k => v.address_prefix }
# }

# output "vpn_gateway_ids" {
#   description = "Resource IDs of VPN Gateways"
#   value       = { for k, v in azurerm_vpn_gateway.vpn_gw : k => v.id }
# }

# output "vpn_gateway_bgp_settings" {
#   description = "BGP settings for VPN Gateways"
#   value       = { for k, v in azurerm_vpn_gateway.vpn_gw : k => v.bgp_settings }
# }

# output "express_route_gateway_ids" {
#   description = "Resource IDs of ExpressRoute Gateways"
#   value       = { for k, v in azurerm_express_route_gateway.er_gw : k => v.id }
# }

# output "p2s_vpn_gateway_ids" {
#   description = "Resource IDs of Point-to-Site VPN Gateways"
#   value       = { for k, v in azurerm_point_to_site_vpn_gateway.p2s_gw : k => v.id }
# }

# output "firewall_ids" {
#   description = "Resource IDs of Azure Firewalls"
#   value       = { for k, v in azurerm_firewall.hub_firewall : k => v.id }
# }

# output "firewall_private_ips" {
#   description = "Private IP addresses of Azure Firewalls"
#   value       = { for k, v in azurerm_firewall.hub_firewall : k => v.virtual_hub[0].private_ip_address }
# }

# output "spoke_vnet_ids" {
#   description = "Resource IDs of Spoke Virtual Networks"
#   value       = { for k, v in azurerm_virtual_network.spoke_vnet : k => v.id }
# }

# output "log_analytics_workspace_id" {
#   description = "Resource ID of the Log Analytics Workspace"
#   value       = azurerm_log_analytics_workspace.vwan_logs.id
# }

# output "resource_group_name" {
#   description = "Name of the resource group"
#   value       = azurerm_resource_group.vwan_rg.name
# }

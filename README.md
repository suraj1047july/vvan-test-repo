# Azure Virtual WAN — Terraform

Complete Terraform configuration for deploying Azure Virtual WAN with all core dependencies.

---

## Architecture

```
Virtual WAN (Standard)
├── Virtual Hub — East US (10.100.0.0/23)
│   ├── VPN Gateway (S2S)
│   ├── ExpressRoute Gateway (optional)
│   ├── P2S VPN Gateway (optional)
│   ├── Azure Firewall + Policy + Rule Collections
│   ├── Custom Route Table
│   └── Spoke VNet Connections
│       ├── vnet-spoke-app  (10.10.0.0/16)
│       └── vnet-spoke-data (10.20.0.0/16)
│
└── Virtual Hub — West Europe (10.101.0.0/23)
    ├── VPN Gateway (S2S)
    ├── Azure Firewall + Policy + Rule Collections
    ├── Custom Route Table
    └── Spoke VNet Connections
        └── vnet-spoke-shared-eu (10.30.0.0/16)

Branch VPN Sites → VPN Gateway Connections (IKEv2 + BGP)
Log Analytics Workspace ← Diagnostic Settings (Firewall logs)
```

---

## Resources Created

| Resource | Count | Notes |
|---|---|---|
| Resource Group | 1 | |
| Virtual WAN | 1 | Standard or Basic |
| Virtual Hub | N | One per region |
| VPN Gateway (S2S) | N | Per hub, toggleable |
| VPN Site | N | Branch/on-prem devices |
| VPN Gateway Connection | N | Hub ↔ Site |
| ExpressRoute Gateway | N | Per hub, toggleable |
| P2S VPN Gateway | N | Per hub, toggleable |
| VPN Server Configuration | N | For P2S (certificate auth) |
| Azure Firewall | N | Per hub, SKU: AZFW_Hub |
| Firewall Policy + Rules | N | App + Network rule collections |
| Hub Route Table | N | Custom routing per hub |
| Spoke Virtual Networks | N | With default subnets |
| Hub VNet Connections | N | Spoke → Hub peering |
| Log Analytics Workspace | 1 | 30-day retention |
| Diagnostic Settings | N | Firewall → Log Analytics |

---

## Prerequisites

- Terraform `>= 1.5.0`
- AzureRM provider `~> 3.100`
- Azure CLI authenticated: `az login`
- Sufficient IAM permissions (Network Contributor + Role-Based Access on subscription)

---

## Quick Start

```bash
# 1. Clone / copy files to your working directory

# 2. Copy and edit the example vars file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your subscription_id and values

# 3. Initialize
terraform init

# 4. Plan
terraform plan -out=tfplan

# 5. Apply
terraform apply tfplan
```

---

## Key Variables

| Variable | Default | Description |
|---|---|---|
| `subscription_id` | — | **Required.** Azure Subscription ID |
| `vwan_type` | `Standard` | `Standard` or `Basic` |
| `virtual_hubs` | 2 hubs | Map of hub configs (see variables.tf) |
| `vpn_sites` | `{}` | On-prem branch VPN sites |
| `spoke_vnets` | 3 vnets | Spoke VNets to attach |
| `tags` | see file | Tags applied to all resources |

---

## Enabling / Disabling Components

Each hub in `virtual_hubs` has toggle flags:

```hcl
deploy_vpn_gateway        = true   # Site-to-Site VPN
deploy_er_gateway         = false  # ExpressRoute
deploy_p2s_gateway        = false  # Point-to-Site VPN
deploy_firewall           = true   # Azure Firewall (Secured Hub)
create_custom_route_table = true   # Custom hub route table
```

Set to `false` to skip deploying that component for that hub.

---

## Security Notes

- **Shared keys** for VPN connections should be stored in Azure Key Vault and referenced via `data` source — do not hardcode in `.tfvars`.
- **P2S certificates** are sensitive; use `sensitive = true` (already set) and backend remote state with encryption.
- Firewall rules are intentionally permissive for RFC 1918 as a starting point — restrict as needed.
- Enable **DDoS Protection Standard** on spoke VNets for production workloads.

---

## Files

```
azure-vwan/
├── main.tf                  # All resources
├── variables.tf             # Input variable definitions + defaults
├── outputs.tf               # Output values
├── terraform.tfvars.example # Copy → terraform.tfvars and fill in
└── README.md                # This file
```

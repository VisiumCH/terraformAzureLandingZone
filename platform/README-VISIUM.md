# Visium platform landing zone

Official Azure [`alz-terraform-accelerator`](https://github.com/Azure/alz-terraform-accelerator/tree/main/templates/platform_landing_zone)
module, configured for Visium's **greenfield-in-parallel** landing zone: a fresh
management-group hierarchy created under the tenant root, alongside the existing
ad-hoc structure, with policy + central logging. Runs in GitHub Actions.

**Goal:** a default, best-practices landing zone that lets us **scale and grow in an
organized way** — structure now so we don't create more work for ourselves later.
Terraform owns the core (management groups, policy, logging); product workloads use
their own IaC (Pulumi) inside their landing zones.

**Onboarding a new project?** See [ONBOARDING.md](ONBOARDING.md) — which path (Visium
Consulting / corp / online), how to request a landing zone, and what it comes with.

**Status:** ✅ core **deployed** (Aug 7 2026) — governance + central logging.
✅ networking + tagging **deployed** (Aug 11 2026) — `Apply complete! 36 added, 2 changed, 0 destroyed`:
two-region hub (`vnet-hub-switzerlandnorth` 172.16.0.0/22 + `vnet-hub-swedencentral` 172.17.0.0/22, peered) and mandatory-tag inheritance.
🟡 network build-out **pending apply** — dedicated connectivity subscription, a third
hub region (France Central), hub subnets and a spoke-peering path. See **[Networking](#networking)**; the hub move needs the one-time migration step
documented there. The rest is migrating subscriptions in and letting workloads (Pulumi)
attach to the hub.

---

## Hierarchy (deployed)

```
Tenant Root
├── visium
│   ├── visium-platform ── visium-management (LAW + Sentinel) / visium-connectivity (hubs, DNS, VPN) / visium-identity
│   ├── visium-landing-zones ── visium-corp / visium-online
│   ├── visium-sandbox   (most migrated workloads; `customer-demo` temp sub-MG)
│   └── visium-decommissioned   (old Management sub `fe2f1af2`, retiring)
└── mg-02 ── landing-zones ── Lonza Devin Pilot   (excluded, do-not-touch — retained)
```

IDs are prefixed **`visium-`** (display names stay clean) because management-group IDs
are **tenant-global** and the pre-existing structure already used `platform` /
`landing-zones` / `sandbox`. 

---

## What was deployed (~540 resources — ~all free governance objects)

| Category | ~Count | Cost | Notes |
|---|---:|---|---|
| Policy role assignments | 210 | free | Managed identities that DINE/Modify policies need to remediate |
| Policy definitions | 149 | free | ALZ built-in policy rules (library `2026.04.2`) |
| Policy assignments | ~118 | free | Applied per MG (audit / deny / DINE) |
| Policy set definitions (initiatives) | 42 | free | Bundles of policies |
| Management groups | 10 | free | The `visium` hierarchy |
| Custom role definitions | 5 | free | e.g. scoped `Subscription-Owner` |
| Log Analytics workspace | 1 | **$** | `law-management-switzerlandnorth` (main cost driver) |
| LA solutions | 2 | free* | ContainerInsights, VMInsights (*bill on ingested data) |
| Data collection rules | 3 | free* | change-tracking / vm-insights / defender-sql (*bill when VMs send data) |
| Resource group + AMA identity | 2 | free | in `sub-visium-management` |
| **Subscription placements** | **0** | — | **deferred** (see next steps) |

Policy assignments per MG: `visium-landing-zones` ~52, `visium-platform` ~40, `visium`
(root) ~20, `visium-identity`/`visium-corp` ~4 each, `visium-sandbox` /
`visium-decommissioned` 1 each. **Deny policies are BLOCKING** — ALZ ships
every `Deny-*` assignment at `enforcement_mode = "Default"` and we never overrode it. What
*is* off is the `Enforce-GR-*` guardrail family (`DoNotEnforce` upstream). `visium-online`
is the permissive product carve-out. Full effective matrix + rollout plan: **[POLICY.md](POLICY.md)**.
Removed `Deploy-MCSB2-Monitoring` (needs Event Hub/Storage diagnostic targets we don't have).

The management sub's resource providers are registered by the pipeline (SP) before apply
(`.github/workflows/platform-landing-zone.yml`), because a brand-new sub has none and
`azapi` doesn't auto-register.

---

## Where each option is configured (which file)

| What | File |
|---|---|
| Region(s), subscriptions, tags, policy tweaks, logging/Sentinel, Defender contact | `management.tfvars` |
| Management-group hierarchy (IDs, parents) | `lib/architecture_definitions/visium.alz_architecture_definition.yaml` |
| Per-MG policy posture (online permissive, root tagging) | `lib/archetype_definitions/*_custom.alz_archetype_override.yaml` |
| Deployment scenario / connectivity type (three-region hub & spoke) | `management.tfvars` → `connectivity_type` + `variables.connectivity.*.tf` |
| Hub regions, address plan, per-hub feature toggles | `management.tfvars` → `starter_locations`, `custom_replacements.names`, `hub_virtual_networks` |
| Spoke-to-hub peering | `management.tfvars` → `spoke_virtual_network_peerings` + `main.connectivity.spoke.peerings.tf` |
| Enforce a policy in audit vs enforce | `management.tfvars` → `policy_assignments_to_modify[...].enforcement_mode` |
| Disable a specific policy assignment | `management.tfvars` → `policy_assignments_to_modify[...].creation_enabled = false` |
| Provider RP registration on new subs | `.github/workflows/platform-landing-zone.yml` (register step) |
| CI (plan on push, apply gated) | `.github/workflows/platform-landing-zone.yml` (`ENABLE_APPLY` var + `production` env) |

Everything else is upstream module code — don't edit; upgrade by replacing from the
accelerator. Kept 1:1 with upstream so it stays diffable.

---

## Networking

Three-region **hub & spoke** (`connectivity_type = "hub_and_spoke_vnet"`, AVM
`avm-ptn-alz-connectivity-hub-and-spoke-vnet`) in the dedicated **connectivity
subscription** `sub-visium-connectivity` (`705238f3-9d51-4fc9-976a-e1859373bdd0`,
under the `visium-connectivity` MG). Detailed toggles live in `management.tfvars`.

```
   ┌────────────────────────────────────────────────────────────────────┐
   │              sub-visium-connectivity (visium-connectivity)         │
   │  hub CH North ◀──mesh──▶ hub Sweden Central ◀──mesh──▶ hub France  │
   │  172.16.0.0/22            172.17.0.0/22             172.18.0.0/22  │
   └──────────────────────────────┬─────────────────────────────────────┘
                                  │ spoke_virtual_network_peerings
                    visium-corp / visium-online spokes
                    (visium-sandbox stays isolated — peering denied by policy)
```

### Regions and address plan

One `/16` per region out of `172.16.0.0/12`; the hub VNet takes the first `/22`
and spokes are carved from the rest of the same `/16`, so one route covers a
whole region. Inside each hub VNet, `x.x.0.0/24` is reserved for platform
services (named and sized whether or not they are deployed) and `x.x.1.0/24`
onwards is hub workload subnets.

| Region | Hub VNet | VNet space | Regional space | Hub subnets |
|---|---|---|---|---|
| Primary — **Switzerland North** | `vnet-hub-switzerlandnorth` | `172.16.0.0/22` | `172.16.0.0/16` | `snet-pep` `172.16.1.32/27` (`172.16.1.0/27` reserved for VPN — AZU-8) |
| Secondary — **Sweden Central** | `vnet-hub-swedencentral` | `172.17.0.0/22` | `172.17.0.0/16` | `snet-pep` `172.17.1.0/27` |
| Tertiary — **France Central** | `vnet-hub-francecentral` | `172.18.0.0/22` | `172.18.0.0/16` | `snet-pep` `172.18.1.0/27` |

Reserved per hub (deployed only when the matching toggle flips): `AzureFirewallSubnet`
`x.x.0.0/26`, `AzureBastionSubnet` `x.x.0.64/26`, `GatewaySubnet` `x.x.0.128/27`,
DNS-resolver `x.x.0.160/28`, `AzureFirewallManagementSubnet` `x.x.0.192/26`.

> ⚠️ **Known overlap.** `vnet01` in Visium Labs (`rg-visium-bench-demo`) is
> `172.16.0.0/26`, inside the primary hub's space. It sits in `visium-sandbox`
> where peering is denied, so it is inert — but that VNet has to be re-addressed
> before Labs could ever become a spoke.

### What is on, and what it costs

| Resource | State | Rough cost |
|---|---|---|
| 3 hub VNets + hub subnets + mesh peering | **on** | free (peering charges per GB transferred) |
| Azure Firewall + policy, Bastion, VPN/ExpressRoute gateway, private DNS zones, DNS resolver, DDoS | **off** (named, sized, subnets reserved) | — |

The whole networking change is roughly **60 resources**, about half of them AVM
telemetry no-ops. That is deliberate: it stays small enough to read a plan line by
line.

**Turning the France firewall on.** Everything is already named, sized and
subnetted; in `management.tfvars` set:

```hcl
tertiary_firewall_enabled              = true
tertiary_firewall_management_ip_enabled = true   # only for Basic SKU / forced tunnelling
```

That deploys `fw-hub-francecentral` + `fwp-hub-francecentral` into
`AzureFirewallSubnet` (`172.18.0.0/26`) and makes the module generate the hub
route tables. Budget roughly **CHF 900/mo** for Standard plus data processing.
The same pattern applies to `primary_*` and `secondary_*`. If you turn a firewall
on, drop `assign_generated_route_table = false` from that hub's subnets so hub
traffic is actually forced through it.

**Private DNS is off in all three hubs, including France.** The France Central
workloads — the customer-demo dataplatform spokes `dp-dev-vnt` (`10.121.0.0/20`)
and `dp-auth-vnt` (`10.125.0.0/24`) — already resolve through the **customer-demo
hub** (`hub-vnt`, `10.120.0.0/24` in `customer-demo-hub-sub`), which runs its own
DNS resolver and 9 private DNS zones in `hub-rsg-dns`. Their 13 private endpoints
use 4 of those zones: `blob`, `dfs`, `vaultcore`, `azuredatabricks`.

Turning the ALZ module's private DNS on here would create a second
`privatelink.blob.core.windows.net` (and vault, dfs, databricks) next to zones that
already serve those exact workloads. Two authoritative zones for one name breaks
resolution as soon as both are linked to a shared VNet, so the platform hubs stay
out of the way until customer-demo leaves the temporary MG — at which point those
**9 real zones migrate here**, rather than the module's full 89-zone catalogue
being instantiated.

To turn it on later, set `tertiary_private_dns_zones_enabled = true` (that also
creates `rg-hub-dns-francecentral`, which is gated on the same toggle). Decide
first which hub owns the global zones: exactly one should have
`private_link_private_dns_zones_regex_filter.enabled = false`; the others must set
it to `true` so they only create region-scoped zones. Curate the set with
`private_link_private_dns_zones` rather than accepting all 89 — across the whole
tenant only 10 service types are actually in use.

### Spoke peering

The hub module meshes the hubs to each other but knows nothing about spokes, so
`main.connectivity.spoke.peerings.tf` creates both directions of each spoke
peering through `azapi` (the spoke side lives in the workload's own subscription).
Add a spoke to `spoke_virtual_network_peerings`:

```hcl
spoke_virtual_network_peerings = {
  my-workload = {
    hub_key                           = "primary"
    spoke_virtual_network_resource_id = "/subscriptions/…/providers/Microsoft.Network/virtualNetworks/vnet-my-workload"
  }
}
```

It is **empty today on purpose**: every migrated workload currently sits in
`visium-sandbox`, where `SandboxDenyVnetPeering` blocks peering and isolation is
deliberate. A spoke becomes eligible once its subscription moves to `visium-corp`
or `visium-online`. The deploy SP needs write access on the spoke VNet as well as
the hub.

### One-time migration: hubs from the management sub to the connectivity sub

The hubs were originally deployed into `sub-visium-management`. Pointing
`subscription_ids.connectivity` at the new sub replaces the hub VNets — `parent_id`
is ForceNew on an `azapi_resource` — but it does **not** move their resource groups:
`azurerm_resource_group` is identified by the resource ID already in state, so
Terraform would go on managing `rg-hub-switzerlandnorth` in the management sub while
the replacement VNet tried to land in a resource group of that name in the
connectivity sub, which does not exist. The apply fails with `ResourceGroupNotFound`
after both hub VNets have already been destroyed.

The fix is the `vnet_*` → `hub_*` key rename in `connectivity_resource_groups`.
Renaming the map key retires the old address (destroyed at its old ID, in the
management sub) and introduces a new one (created in the connectivity sub), so the
move is declarative and the pipeline completes it in a single apply. This matters
because the deploy SP is the only identity with Storage Blob Data access to the
state container — nobody can run `terraform state` commands or `-replace` by hand.

Expect the plan to show, for each of the two existing hubs: the VNet replaced, its
two mesh peerings replaced, the old resource group destroyed and a new one created.
Both hub VNets are empty — no subnets, no workloads, only the hub-to-hub peering —
so nothing carrying traffic is destroyed. Afterwards confirm `rg-hub-switzerlandnorth`
and `rg-hub-swedencentral` are gone from `sub-visium-management` and present in
`sub-visium-connectivity`.

Also still open: the `customer-demo` France Central hub (`hub-vnt`, `10.120.0.0/24`
in `customer-demo-hub-sub`) is a separate, temporary hub with its own firewall and
DNS resolver. It is not peered to the platform hubs and is out of scope here.

---

## Sandbox policy reference — what actually blocks a deployment

Complete set effective on **any `visium-sandbox` subscription** — the sandbox guardrail
(`Enforce-ALZ-Sandbox`) plus everything inherited from the `visium` root. **20 rules
total, but only 4 block anything.**

**🔴 DENY — block deployment (the only ones you can hit)**

| Policy | What it blocks |
|---|---|
| `SandboxDenyVnetPeering` | Any VNet peering (sandbox-specific) |
| `SandboxNotAllowed` | Gateways / hybrid networking — VPN, ExpressRoute, vWAN, virtual network gateways (9 types) |
| `Deny-Classic-Resources` | Classic (ASM-era) resources |
| `Deny-UnmanagedDisk` | VMs / scale sets without managed disks |

Only these four can fail a deploy. The first two (sandbox-specific) are pre-waived for
the `customer-demo` subs via scoped policy exemptions (category `Waiver`). Public
endpoints + IP-forwarding **are allowed** in sandbox.

**🟡 AUDIT — flag only, never block:** `Audit-TrustedLaunch`, `Audit-UnusedResources`,
`Audit-ResourceRGLocation`, `Audit-ZoneResiliency`, `Enforce-ACSB`.

**🟢 DEPLOY-IF-NOT-EXISTS — auto-deploy governance, don't block:**
`Deploy-SvcHealth-BuiltIn`, `Deploy-Diag-LogsCat`, `Deploy-AzActivity-Log`,
`Deploy-MDFC-Config-H224`, `Deploy-MDEndpoints`, `Deploy-MDFC-SqlAtp`,
`Deploy-MDFC-OssDb`. These create the "+3 governance resources" per sub and re-point
diagnostics — additive.

**🔵 MODIFY — add tags, don't block:** `inherit-tag-project` / `-costcenter` /
`-environment` / `-owner` (inherit the 4 required tags from the RG/sub onto resources).

> ⚠️ `Merge` overwrites an existing tag value, and Azure tag keys are **case-insensitive**
> (`Owner` vs `owner` collide). On richly-tagged subs, fill only missing keys.

---

## Next steps / what's missing

1. **Networking** — built out in `management.tfvars`; see **[Networking](#networking)**
   for the address plan, what is on and what it costs, how to turn the firewall on, and
   the one-time hub migration into the connectivity subscription. Still deliberately
   **off**: Azure Firewall, Bastion, VPN/ExpressRoute gateways, private DNS zones and
   resolver, and the DDoS plan. Also still off platform-wide: Azure Monitor Agent
   (`management_resource_settings` / policy), monitoring baseline alerts, and Defender
   for Cloud plans (`policy_assignments_to_modify` → `Deploy-MDFC-Config`).

   Decisions on record: primary **Switzerland North** (billing, existing resources, Swiss
   residency — the LAW is already there) + secondary **Sweden Central** (LLM/GPU, DR),
   confirmed by Pascal Aug 2026; tertiary **France Central** for customer workloads, agreed
   with Daniel 14/08. Address ranges follow the accelerator's documented multi-region
   defaults (`172.16.0.0/16` per region), signed off at the Aug 2026 IP meeting.
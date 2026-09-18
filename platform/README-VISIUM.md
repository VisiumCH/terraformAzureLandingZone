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
two-region hub (`vnet-hub-switzerlandnorth` 172.16.0.0/22 + `vnet-hub-swedencentral` 172.17.0.0/22, peered) and mandatory-tag inheritance. Platform Terraform is effectively complete; the rest is migrating subscriptions in and letting workloads (Pulumi) attach to the hub.

---

## Hierarchy (deployed)

```
Tenant Root
├── visium
│   ├── visium-platform ── visium-management (LAW + Sentinel) / visium-connectivity / visium-identity
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
| Deployment scenario / connectivity type (`none` today; multi-region hub-spoke next) | `management.tfvars` → `connectivity_type` + `variables.connectivity.*.tf` |
| Enforce a policy in audit vs enforce | `management.tfvars` → `policy_assignments_to_modify[...].enforcement_mode` |
| Disable a specific policy assignment | `management.tfvars` → `policy_assignments_to_modify[...].creation_enabled = false` |
| Provider RP registration on new subs | `.github/workflows/platform-landing-zone.yml` (register step) |
| CI (plan on push, apply gated) | `.github/workflows/platform-landing-zone.yml` (`ENABLE_APPLY` var + `production` env) |

Everything else is upstream module code — don't edit; upgrade by replacing from the
accelerator. Kept 1:1 with upstream so it stays diffable.

---

## Networking

Multi-region **hub & spoke** (`connectivity_type = "hub_and_spoke_vnet"`, AVM
`avm-ptn-alz-connectivity-hub-and-spoke-vnet`), deployed **minimal** to keep costs
down. Detailed toggles live in `management.tfvars` (see the table in *Next steps* §1).

### How it's done now (deployed)

Both hub VNets currently land in the **management subscription**
(`sub-visium-management`) — `subscription_ids.connectivity` points at it, so there is
**no dedicated connectivity sub yet**.

| Region | Hub VNet | VNet space | Regional space |
|---|---|---|---|
| Primary — **Switzerland North** | `vnet-hub-switzerlandnorth` | `172.16.0.0/22` | `172.16.0.0/16` |
| Secondary — **Sweden Central** | `vnet-hub-swedencentral` | `172.17.0.0/22` | `172.17.0.0/16` |

**OFF everywhere** (names reserved, not deployed): Azure Firewall + policy, Bastion,
VPN gateway, ExpressRoute gateway, DDoS plan, Private DNS zones, Private DNS resolver.
Hub subnets are empty. **No spokes peered yet** — migrated workloads sit in
`visium-sandbox`, where `SandboxDenyVnetPeering` **denies peering** (VNets are
deliberately isolated). The `customer-demo` temp MG has a scoped waiver so its spokes
can peer to a demo hub.

### VPN — Tailscale subnet routers (AZU-8)

Remote access is Tailscale, not a VPN gateway. Two subnet routers
(`vm-tailscale-chn-01`, `vm-tailscale-chn-02`) sit in the Switzerland North hub's
`snet-vpn` (`172.16.1.0/27`), one per availability zone, both advertising the
regional hub spaces. Tailscale fails over between routers advertising the same
routes, so either one can be lost.

Deployed by `main.connectivity.tailscale.tf`, configured under
`tailscale_subnet_routers` in `management.tfvars`:

- **Public IPs on purpose.** A public IP lets Tailscale build direct UDP
  connections instead of relaying through DERP. The NSG allows only UDP 41641
  from the internet and anything from the tailnet CGNAT range `100.64.0.0/10`;
  Azure's default rules deny the rest, so there is no inbound SSH. Creating them
  fires the public-resource Slack alert — expected, not a surprise.
- **IP forwarding** is on at the NIC (Azure side) and via sysctl (OS side). Both
  are required; a subnet router with only one of them looks healthy and silently
  fails to route.
- **SNAT stays on** (Tailscale's default), so replies from Azure workloads return
  through the router and no spoke needs a route for `100.64.0.0/10`.
- **Access** is Tailscale SSH. The generated break-glass key is the sensitive
  output `tailscale_break_glass_private_key`, usable only from inside the tailnet
  or the serial console.
- **Auth key** comes from the `TAILSCALE_AUTH_KEY` repo secret (reusable,
  pre-approved, tagged). It is passed through cloud-init, so rotate it once the
  routers are up. `custom_data` is in `ignore_changes`: cloud-init only runs on
  first boot, so re-rendering it must not silently replace a working router —
  rebuild deliberately with `terraform taint`.

**After the first apply**, in the Tailscale admin console: approve both machines,
then approve their advertised subnet routes. Nothing routes until you do.

**Replacing the Pulumi router.** The original `tailscale-router` VM lives in
`rg-hub-shared-dev` in the **Visium Consulting** subscription (`f12e214d…`), tagged
`managed-by: pulumi`, project `azure-hub-infrastructure`. It stays up during the
cutover. Two things to know when comparing behaviour:

- Its NIC has **`enableIPForwarding` unset**, so Azure drops any packet it tries to
  forward on behalf of another host. It can serve as a tailnet node but not as a
  working subnet router. The new routers set it explicitly.
- It reaches the internet through a NAT gateway with no public IP of its own, so its
  Tailscale connections relay through DERP rather than connecting directly.

Once the new routers are approved and verified, remove the old one from its Pulumi
stack and delete the machine in the Tailscale console. Still open for this ticket:
streaming Tailscale audit logs to the central workspace, and writing down the
access/onboarding process.

**Note on ordering.** This branch is written against `main`. AZU-14 moves the hubs
into the dedicated connectivity subscription and adds the France Central region; if
that lands first, rebase this branch onto it and extend
`tailscale_advertise_routes` with `172.18.0.0/16`.

---

### Target (AZU-14)

- **Dedicated connectivity subscription** — split hubs out of the management sub into `visium-connectivity`.
- **France Central hub** (per Daniel) — additional region + VNet; needs **Azure Firewall + Private DNS**.
- **Turn on hub services** as need arises: Azure Firewall (+ policy), Bastion, **VPN / ExpressRoute gateway** for hybrid/on-prem, **Private DNS zones + resolver** for Private Link, DDoS plan when justified.
- **Spoke peering** for corp/online landing zones → hub. **Sandbox stays isolated** (no peering, by policy); read-only outside sandbox.
- **Hub-to-hub peering** CH North ⇄ Sweden Central ⇄ France Central for DR / cross-region routing.
- **Tailscale** as the interim/overlay VPN + one consolidated VPN-logging solution (AZU-8).

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

1. **Networking — multi-region hub-and-spoke**
   (`connectivity_type = "hub_and_spoke_vnet"` in `management.tfvars`). **Minimal by
   design — everything expensive is off**, so cost is ~€tens/mo (two VNets only).

   | Setting | Decision | Where |
   |---|---|---|
   | Scenario | Multi-region hub & spoke (primary + one DR region) | `connectivity_type = "hub_and_spoke_vnet"` |
   | **Azure Firewall** | **OFF** (keep costs down — NSGs + private endpoints instead). No firewall ⇒ the hub is just a VNet + private DNS (minimal, cheap). | `primary/secondary_firewall_enabled = false` |
   | Region | ✅ **Confirmed (Pascal, Aug 2026):** primary **Switzerland North** (billing + existing resources + Swiss residency; LAW already here → no churn) + secondary **Sweden Central** (LLM/GPU + DR). | `starter_locations` (primary first) |
   | Bastion host | **OFF** | `primary/secondary_bastion_enabled = false` |
   | Private DNS zones | **OFF** — no private endpoints in the new LZ yet; a workload gets its own zone when it creates one (or we add specific zones to the hub then). | `primary/secondary_private_dns_zones_enabled = false` |
   | Private DNS resolver | **OFF** (cost) | `primary/secondary_private_dns_resolver_enabled = false` |
   | Virtual network gateways | **OFF** | `..._gateway_express_route_enabled` / `..._vpn_enabled = false` |
   | DDoS protection plan | **OFF** | `ddos_protection_plan_enabled = false` |
   | IP address ranges | ✅ **Confirmed (IP meeting, Aug 2026):** use the accelerator's **documented multi-region defaults** — `172.16.0.0/16` (primary) + `172.17.0.0/16` (secondary). Verified non-overlapping (all existing VNets are `10.x`; 172.16/12 is a separate block). | `custom_replacements.names` |
   | Connectivity subscription | the **Management sub** for now (no dedicated connectivity sub yet) — hub + DNS land there | `subscription_ids.connectivity` |
   | Azure Monitor Agent (AMA) | **OFF** for now | `management_resource_settings` / policy |
   | Monitoring baseline alerts | **OFF** for now | management resources |
   | Defender for Cloud plans | **OFF** for now | `policy_assignments_to_modify` (Deploy-MDFC-Config) |
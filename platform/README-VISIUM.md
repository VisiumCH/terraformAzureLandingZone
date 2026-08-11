# Visium platform landing zone

Official Azure [`alz-terraform-accelerator`](https://github.com/Azure/alz-terraform-accelerator/tree/main/templates/platform_landing_zone)
module, configured for Visium's **greenfield-in-parallel** landing zone: a fresh
management-group hierarchy created under the tenant root, alongside the existing
ad-hoc structure, with policy + central logging. Runs in GitHub Actions.

**Goal:** a default, best-practices landing zone that lets us **scale and grow in an
organized way** — structure now so we don't create more work for ourselves later.
Terraform owns the core (management groups, policy, logging); product workloads use
their own IaC (Pulumi) inside their landing zones.

**Status:** ✅ core **deployed** (Aug 7 2026) — `Apply complete! 0 changed, 0 destroyed`.

---

## Hierarchy (deployed)

```
Tenant Root
└── visium
    ├── visium-platform ── visium-management (LAW + Sentinel) / visium-connectivity / visium-identity
    ├── visium-landing-zones ── visium-corp / visium-online
    ├── visium-sandbox
    └── visium-decommissioned
```

IDs are prefixed **`visium-`** (display names stay clean) because management-group IDs
are **tenant-global** and the pre-existing structure already used `platform` /
`landing-zones` / `sandbox`. All groups are created new; **no subscriptions moved yet.**

## Structure before the change (pre-existing, untouched)

Under the Tenant Root Group there were already ~16 management groups from earlier ad-hoc
work — including `mg-02`, `platform`, `landing-zones`, `sandbox`, and `Data Platform`,
plus the 14 existing subscriptions. **None of these were modified.** They are migrated
into the new `visium` tree later, one at a time, and the old groups retired into
`visium-decommissioned` (plan §5). The two new subscriptions (`sub-visium-management`
`8745729a…`, `sub-visium-online` `fc00db1c…`) were created for this build and currently
sit directly under the Tenant Root Group until moved.

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
| Microsoft Sentinel onboarding | 1 | **$** | onboarded onto the workspace (state name `default`) |
| Resource group + AMA identity | 2 | free | in `sub-visium-management` |
| **Subscription placements** | **0** | — | **deferred** (see next steps) |

Policy assignments per MG (audit-first): `visium-landing-zones` ~52, `visium-platform`
~40, `visium` (root) ~16, `visium-identity`/`visium-corp` ~4 each, `visium-sandbox` /
`visium-decommissioned` 1 each. Deny policies start **non-blocking (audit / DoNotEnforce)**;
`visium-online` is permissive (product carve-out). Removed `Deploy-MCSB2-Monitoring`
(needs Event Hub/Storage diagnostic targets we don't have).

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

## Next steps / what's missing

1. **Networking — multi-region hub-and-spoke**
   (`connectivity_type = "hub_and_spoke_vnet"` in `management.tfvars`). **Minimal by
   design — everything expensive is off**, so cost is ~€tens/mo (two VNets only).
   Not yet applied: validate first via **Actions → Run workflow** (dispatch = plan only) on
   this branch, and confirm IP sign-off (below), then merge to apply.
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
2. **Subscription placement — DONE (manually).** `sub-visium-management` → `visium-management`
   and `sub-visium-online` → `visium-online` were moved in the portal (Aug 2026). We keep
   `subscription_placement = {}` in Terraform on purpose: the deploy SP's role assignments
   are ABAC-conditioned and can't manage MG placement, so moves are done in the portal by a
   privileged account (elevate access → grant self Management Group Contributor → move → revert).
3. **Mandatory tagging policy — IMPLEMENTED** in `main.tagging.tf`: the built-in
   *"Inherit a tag from the resource group"* (Modify, non-blocking) is assigned once per
   required tag (`project` / `cost-center` / `environment` / `owner`) at the `visium` root,
   each with a system-assigned identity + **Tag Contributor** role for remediation. Resources
   inherit the tag from their RG — adds tags without blocking. Validate via dispatch-plan.
4. **Microsoft Sentinel data connectors** (Azure Activity / Entra ID / Defender).
   Terraform onboards Sentinel; connectors live in Pascal's Pulumi repo →
   **[VisiumCH/azure-infra — security-infra/security/sentinel.py](https://github.com/VisiumCH/azure-infra/blob/main/security-infra/security/sentinel.py)**.
   Decide ownership so Terraform and Pulumi don't both manage the workspace/Sentinel.
5. **PIM / least privilege** — roll off standing admin; eligible JIT roles (Entra, not here).
6. **Migrate the 14 existing subscriptions** from the old tree into `visium-*`, one at a time.


## Before an apply
- `ENABLE_APPLY=true` repo variable is set; apply runs on push to `main` and is gated by
  the `production` environment approval.
- Deploy SP `tf-alz-manager` needs its roles at the tenant root (management-group +
  policy + role-assignment) — already granted.

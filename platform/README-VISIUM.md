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

1. **Networking — move to multi-region hub-and-spoke** (currently `connectivity_type = "none"`).
   Agreed configuration for the next iteration:
   | Setting | Decision | Where |
   |---|---|---|
   | Scenario | Multi-region hub & spoke (one primary + **one extra region** for DR) | accelerator scenario → `connectivity_type` + `starter_locations` |
   | Region | Primary **Germany West Central** (cheaper/more services than Switzerland North — confirm with Pascal) | `starter_locations` |
   | Bastion host | **OFF** | connectivity vars |
   | Private DNS zones | **KEEP ON** | connectivity vars |
   | Virtual network gateways | **OFF** | connectivity vars |
   | DDoS protection plan | **OFF** | already `creation_enabled = false` |
   | IP address ranges | **TBD** — company is small so not urgent, but **schedule a planning meeting** | connectivity vars |
   | Azure Monitor Agent (AMA) | **OFF** for now | `management_resource_settings` / policy |
   | Monitoring baseline alerts | **OFF** for now | management resources |
   | Defender for Cloud plans | **OFF** for now | `policy_assignments_to_modify` (Deploy-MDFC-Config) |
2. **Move the two new subscriptions** into `visium-management` / `visium-online`
   (`subscription_placement` is currently `{}`). Needs *unconstrained* role-assignment
   rights on the subs — the deploy SP's roles are ABAC-conditioned, which fails the
   sub-move check. Either a sub-owner/GA moves them in the portal, or re-grant the SP
   unconditioned User Access Administrator / Owner and re-add `subscription_placement`.
3. **Mandatory tagging policy** — activate (scaffold in `lib/archetype_definitions/root_custom…`).
   Subscriptions carry text tags today, but the enforcing policy isn't assigned yet.
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

# Platform Landing Zone — Visium setup (GitOps, no local tools)

This folder is the official ALZ `platform_landing_zone` template, configured to **adopt**
Visium's existing management-group hierarchy and add governance. It runs entirely in
GitHub Actions. Your existing AVM workload project at the repo root is untouched.

## What this first pass does (Phase 1 — safe)
- **Adopts** the existing `platform` and `landing-zones` management groups under `mg-02`
  (`exists: true` in `lib/architecture_definitions/visium.alz_architecture_definition.yaml`)
  — no groups created, **no subscriptions moved**.
- Applies the ALZ **policy archetypes** and deploys **management resources** (Log Analytics,
  DCRs, AMA identity) into the `Management` subscription.
- **No networking** (`connectivity_type = "none"`) — nothing to bill or break yet.
- `sandbox` and `data-platform` (which sit outside `mg-02`) are **out of scope** for now.

## The one prerequisite you can't set yourself
The GitHub Actions deploy identity needs elevated rights that Reader can't grant. Ask whoever
owns the tenant root to give the **deploy service principal**:
- **Owner + User Access Administrator on `mg-02`** (`/providers/Microsoft.Management/managementGroups/mg-02`)
- **Owner on the `Management` subscription** (`fe2f1af2-1bb4-4502-b622-383217ac1f0b`)
Then put its client ID into the `ALZ_AZURE_CLIENT_ID` secret below.

## GitHub repo secrets to add (Settings → Secrets and variables → Actions)
| Secret | Value |
|---|---|
| `ALZ_AZURE_CLIENT_ID` | client ID of the elevated deploy SP |
| `AZURE_TENANT_ID` | your tenant ID |
| `ALZ_MANAGEMENT_SUBSCRIPTION_ID` | `fe2f1af2-1bb4-4502-b622-383217ac1f0b` |
| `STORAGE_ACCOUNT_STATE` | your existing state storage account |
| `ALZ_STATE_RG` | resource group of that storage account |
| `ALZ_STATE_CONTAINER` | a container for platform state (can reuse; key is separate) |

Also add the SP as a federated credential on the repo (subject `repo:VisiumCH/terraformAzureLandingZone:ref:refs/heads/main`
and one for `pull_request`), and create a `production` GitHub Environment with required reviewers.

## How to run
1. Put `platform/` in the repo and `.github/workflows/platform-landing-zone.yml` in place.
2. Open a **pull request** → the `plan` job runs (read-only, safe) and shows exactly what would change.
3. **Review the plan together** — confirm it adopts (not recreates) the groups and moves no subs.
4. Merge → `apply` runs, **gated by manual approval** in the `production` environment.

## Review BEFORE first apply (important)
- **Policy enforcement:** ALZ archetypes include some Deny / DeployIfNotExists policies. On a live
  tenant, consider running them in audit first. Check the plan; set assignment `enforcement_mode`
  to `DoNotEnforce` where you want audit-only to start.
- **`subscription_ids` validation** may require `connectivity`/`identity` keys — if `plan` complains,
  add them (can point at `Management` temporarily) or trim required keys.
- This config is a **first draft validated by `plan`**. The first plan output is the source of
  truth; adjust `management.tfvars` / the architecture from what it shows.

## Phase 2 (later, deliberate PRs)
Add standard depth (`management`/`connectivity`/`identity` under platform, `corp`/`online` under
landing-zones, `decommissioned`), bring `sandbox`/`data-platform` under governance (needs SP rights
at the tenant root), add hub networking, then retire the ad-hoc `mg-02` naming.

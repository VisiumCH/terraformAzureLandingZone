# Visium platform landing zone

Official Azure [`alz-terraform-accelerator`](https://github.com/Azure/alz-terraform-accelerator)
module, configured for Visium's **greenfield-in-parallel** landing zone: a fresh
management-group hierarchy created under the tenant root, alongside the existing
`mg-02` tree, with policy + central logging. Runs in GitHub Actions (plan on PR,
apply gated behind `ENABLE_APPLY` + the `production` environment).

## Hierarchy

```
Tenant Root
└── visium
    ├── platform ── management (LAW + Sentinel) / connectivity / identity
    ├── landing-zones ── corp / online (permissive)
    ├── sandbox
    └── decommissioned
```

All groups are created new. The 14 existing subscriptions stay in `mg-02` and are
migrated in later, one at a time; only the `Management` subscription moves now.

## Files you edit

| File | Purpose |
|---|---|
| `management.tfvars` | region, subscriptions + placement, tags, policy, logging/Sentinel |
| `lib/architecture_definitions/visium.*.yaml` | the management-group hierarchy |
| `lib/archetype_definitions/*_custom.*.yaml` | per-MG policy posture |

Everything else is upstream module code — don't edit it; upgrade by replacing from
the accelerator. `variables.connectivity.*.tf` / `main.connectivity.*.tf` are unused
while `connectivity_type = "none"` but kept so the tree matches upstream 1:1.

## Before the first apply

- Set `root_parent_management_group_id` in `management.tfvars` to the tenant id
  (placeholder `REPLACE_WITH_TENANT_ROOT_ID`).
- Grant the deploy SP `tf-alz-manager` least-privilege at the **tenant root**:
  Management Group Contributor + Resource Policy Contributor + RBAC Administrator,
  plus Owner on the Management subscription. Done by the tenant owner out-of-band.
- Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
  `STORAGE_ACCOUNT_STATE`, `CONTAINER_STATE`. Set repo var `ENABLE_APPLY=true` to
  allow apply.
- Deny policies start audit-only; enforce deliberately per MG from the plan output.

## Not in this Terraform (plan follow-ups)

- **Sentinel data connectors** (Azure Activity, Entra ID, Defender) — the module
  onboards Sentinel but doesn't manage connectors.
- **PIM / least privilege** — configured in Entra PIM.
- **Partner credits** — enabling creates a new subscription; add it under `online`.
- **Tagging policy** — wire the built-in tag Modify policies in `root_custom`.

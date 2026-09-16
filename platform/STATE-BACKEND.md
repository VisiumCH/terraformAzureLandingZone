# IaC state backend

Runbook for consolidating Terraform and Pulumi state onto one platform-owned storage
account. Tracks [AZU-17](https://linear.app/visium/issue/AZU-17/centralize-iac-terraform-and-pulumi-states).

## Today

| Stack | State | Subscription | Region | Auth |
|---|---|---|---|---|
| platform LZ (this repo) | `sttfstatesvisium` / `tfstateplatform` / `platform-landing-zone.tfstate` | `f12e214d` Visium Consulting | germanywestcentral | OIDC + Entra |
| `VisiumCH/azure-infra` (Pulumi) | `stpulumistate0` / `pulumi-state` | `f12e214d` Visium Consulting | switzerlandnorth | storage account key |

Both accounts sit in a **sandbox** subscription, both allow shared-key access, and both
have `publicNetworkAccess: Enabled` with `networkRuleSet.defaultAction: Allow`. State
holds every secret those stacks manage.

## Target

| | Value |
|---|---|
| Subscription | `sub-visium-management` `8745729a-505a-4910-aaaf-d53b9cdc8883` |
| RG / region | `rg-iac-state-switzerlandnorth` / Switzerland North |
| Account | `stvisiumiacstate` — Standard_ZRS, shared-key access off, TLS 1.2, HTTPS only, blob versioning + 30-day soft delete |
| Containers | `tfstate-platform`, `tfstate-workloads`, `pulumi-state` |

One account, one container per class of state, one blob key per stack. Access is Entra
only, granted per container:

| Principal | Object id | Container |
|---|---|---|
| `tf-alz-manager` | `9fd28842-aec8-4bac-888c-21cfd5dcfea5` | `tfstate-platform` |
| `gh-actions-azure-infra` | `03f2c27a-c225-44dc-91c9-6675ac8026ef` | `pulumi-state` |
| per-subscription workload SPs | — | `tfstate-workloads` |

Turning shared-key access off also makes the account pre-compliant with
`Enforce-GR-Storage0`, which will eventually apply at `visium-platform`
(see [POLICY.md](POLICY.md)).

## Build

`Microsoft.Storage` is **not registered** on the management subscription — the
greenfield sub never needed it. The register step in
`.github/workflows/platform-landing-zone.yml` now includes it; register it once by hand
before creating anything.

```bash
az provider register --namespace Microsoft.Storage --subscription 8745729a-505a-4910-aaaf-d53b9cdc8883 --wait
```

```bash
az group create --name rg-iac-state-switzerlandnorth --location switzerlandnorth --subscription 8745729a-505a-4910-aaaf-d53b9cdc8883 --tags project=platform-landing-zone cost-center=platform environment=platform owner=cloud@visium.ch
```

```bash
az storage account create --name stvisiumiacstate --resource-group rg-iac-state-switzerlandnorth --subscription 8745729a-505a-4910-aaaf-d53b9cdc8883 --location switzerlandnorth --sku Standard_ZRS --kind StorageV2 --min-tls-version TLS1_2 --https-only true --allow-blob-public-access false --allow-shared-key-access false --public-network-access Enabled
```

```bash
az storage account blob-service-properties update --account-name stvisiumiacstate --resource-group rg-iac-state-switzerlandnorth --subscription 8745729a-505a-4910-aaaf-d53b9cdc8883 --enable-versioning true --enable-delete-retention true --delete-retention-days 30 --enable-container-delete-retention true --container-delete-retention-days 30
```

```bash
for c in tfstate-platform tfstate-workloads pulumi-state; do az storage container create --name "$c" --account-name stvisiumiacstate --auth-mode login; done
```

Role assignments need `Microsoft.Authorization/roleAssignments/write`, which Contributor
at `visium` does not carry — this step needs Platform Admins (Owner at `visium`) or an
elevated Global Admin.

```bash
SA=/subscriptions/8745729a-505a-4910-aaaf-d53b9cdc8883/resourceGroups/rg-iac-state-switzerlandnorth/providers/Microsoft.Storage/storageAccounts/stvisiumiacstate; az role assignment create --assignee-object-id 9fd28842-aec8-4bac-888c-21cfd5dcfea5 --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope "$SA/blobServices/default/containers/tfstate-platform"; az role assignment create --assignee-object-id 03f2c27a-c225-44dc-91c9-6675ac8026ef --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope "$SA/blobServices/default/containers/pulumi-state"
```

```bash
az lock create --name iac-state-no-delete --lock-type CanNotDelete --resource-group rg-iac-state-switzerlandnorth --subscription 8745729a-505a-4910-aaaf-d53b9cdc8883
```

## Migrate

**Terraform.** Run from `platform/` with `ENABLE_APPLY=false` and no pipeline run in
flight.

```bash
terraform init -migrate-state -force-copy -backend-config="storage_account_name=stvisiumiacstate" -backend-config="container_name=tfstate-platform" -backend-config="key=platform-landing-zone.tfstate" -backend-config="subscription_id=8745729a-505a-4910-aaaf-d53b9cdc8883" -backend-config="tenant_id=b7418ead-a445-4708-a309-951ab14852eb" -backend-config="use_azuread_auth=true"
```

Then repoint the repo secrets `STORAGE_ACCOUNT_STATE` → `stvisiumiacstate` and
`CONTAINER_STATE` → `tfstate-platform`. A PR plan returning `0 to add, 0 to change,
0 to destroy` is the proof the migration worked.

**Pulumi.** Six stacks across four projects: `security-infra` (`prod`, `visium`),
`hub-infra` (`dev`, `prod`), `spoke-infra` (`CENT-IncidReducAgentUseCa-2601-dev`),
`swisstopo-infra` (`prod`). Per stack, with the existing `PULUMI_CONFIG_PASSPHRASE`:

```bash
pulumi stack export --stack <stack> --file /tmp/<stack>.json && pulumi login "azblob://pulumi-state?storage_account=stvisiumiacstate" && pulumi stack init <stack> && pulumi stack import --file /tmp/<stack>.json
```

`pulumi preview` must come back empty before starting the next stack.

The Pulumi CD workflows currently run `az storage account keys list` and export
`AZURE_STORAGE_KEY`; that step dies against an account with shared-key access off. The
replacement is dropping those steps and setting `AZURE_STORAGE_AUTH_MODE=login` so the
azblob backend uses the OIDC credential from `azure/login@v2`. **Prove this on
`swisstopo-infra/prod` first** — smallest and most isolated stack.

## Accepted risk

The account cannot be private. GitHub-hosted runners come from public IPs, so
`publicNetworkAccess` stays `Enabled` on the one account holding every secret in state.
Entra-only auth plus container-scoped RBAC is the compensating control, and Owner at
`visium` grants no blob data-plane access — Platform Admins cannot read state by
default.

Closing the gap means self-hosted runners in the hub VNet. Until then this account needs
an exemption from `Enforce-GR-Storage0`'s `storageAccountNetworkRules = Deny`.

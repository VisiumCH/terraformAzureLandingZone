# terraformAzureLandingZone

Terraform project deploying a foundational Azure landing zone using [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/).

## Resources Deployed

| Resource | Module | Naming Convention |
|---|---|---|
| Resource Group | `avm-res-resources-resourcegroup` v0.2.2 | `rg-{app}-{location}` |
| Storage Account | `avm-res-storage-storageaccount` v0.6.7 | `st{app}02` |
| Log Analytics Workspace | `avm-res-operationalinsights-workspace` v0.5.1 | `law-{app}-{location}` |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.x
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) — authenticated via `az login`
- An Azure Storage Account and container for remote state (backend)

## Variables

| Variable | Type | Description |
|---|---|---|
| `application_name` | `string` | Short name used in resource naming |
| `primary_location` | `string` | Azure region (e.g. `germanywestcentral`) |
| `containers` | `map(object)` | Blob containers to create in the storage account |
| `tenant_id` | `string` | Azure AD Tenant ID |

## Running Locally

```bash
# 1. Authenticate
az login

# 2. Initialize with backend config
terraform init \
  -backend-config="tenant_id=<TENANT_ID>" \
  -backend-config="storage_account_name=<SA_NAME>" \
  -backend-config="container_name=<CONTAINER>" \
  -backend-config="key=dev.terraform.tfstate" \
  -backend-config="subscription_id=<SUBSCRIPTION_ID>"

# 3. Plan
terraform plan -var-file="dev.tfvars"

# 4. Apply
terraform apply -var-file="dev.tfvars"
```

## CI/CD

GitHub Actions pipeline (`.github/workflows/terraform.yml`) runs on push to `main`:

1. **Plan** — runs `terraform plan` and uploads the plan as an artifact
2. **Apply** — downloads the plan and applies it, gated by the **`production`** GitHub Environment (requires manual approval)

Authentication uses **OIDC** (federated identity) — no long-lived secrets stored in GitHub.

### Required GitHub Secrets & Variables

| Name | Type | Description |
|---|---|---|
| `AZURE_CLIENT_ID` | Secret | App Registration client ID |
| `AZURE_TENANT_ID` | Secret | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Secret | Azure subscription ID |
| `STORAGE_ACCOUNT_STATE` | Secret | Storage account name for Terraform state |
| `CONTAINER_STATE` | Secret | Container name for Terraform state |
| `KEY_STATE` | Secret | State file key/path |
| `application_name` | Variable | App name used in resource naming |
| `primary_location` | Variable | Azure region |
| `containers` | Secret | JSON-encoded containers map |
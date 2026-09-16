# Policy enforcement audit

Library: `platform/alz` **2026.04.2**. All policy definitions and initiatives are
deployed once at the **`visium`** root MG; assignments reference them from any
descendant MG. That is why a policy can be assigned at `visium-online` even though the
upstream `online` archetype ships empty.

What ALZ ships **off** (`DoNotEnforce`): the 30 `Enforce-GR-*`
per-service guardrail initiatives, plus `Enforce-Subnet-Private` and
`Enforce-Encrypt-CMK0`, at both `visium-landing-zones` and `visium-platform`.

### Live exemptions

| Name | Scope | Assignment | Rules | Expires |
|---|---|---|---|---|
| `customer-demo-networking` | MG `customer-demo` | `Enforce-ALZ-Sandbox` | `SandboxDenyVnetPeering`, `SandboxNotAllowed` | none — temp MG |
| `consulting-sandbox-peering` | sub `f12e214d` | `Enforce-ALZ-Sandbox` | `SandboxDenyVnetPeering` | none |
| `dp-sandbox-networking` | sub `8bec8b7e` | `Enforce-ALZ-Sandbox` | `SandboxDenyVnetPeering`, `SandboxNotAllowed` | none |

## Effective matrix

| MG | Blocking | Assigned, non-blocking |
|---|---|---|
| `visium` (root) | `Deny-Classic-Resources`, `Deny-UnmanagedDisk` | — |
| `visium-landing-zones` | `Deny-Subnet-Without-Nsg`, `Deny-Storage-http`, `Deny-IP-forwarding`, `Deny-MgmtPorts-Internet`, `Deny-Priv-Esc-AKS`, `Deny-Privileged-AKS`, `Enforce-AKS-HTTPS`, `Enforce-TLS-SSL-Q225`, `Enforce-GR-KeyVault` | 29 × `Enforce-GR-*`, `Enforce-Encrypt-CMK0` |
| `visium-corp` | `Deny-Public-Endpoints` (45 PaaS services), `Deny-Public-IP-On-NIC`, `Deny-HybridNetworking` | — |
| `visium-online` | *(inherits landing-zones + root only)* | `Deny-Public-Endpoints` — audit-only |
| `visium-platform` | `Enforce-ASR`, `Enforce-GR-KeyVault`, AMA/GuestAttest DINE | 29 × `Enforce-GR-*`, `Enforce-Subnet-Private`, `Enforce-Encrypt-CMK0` |
| `visium-identity` | `Deny-Public-IP`, `Deny-MgmtPorts-Internet`, `Deny-Subnet-Without-Nsg` | — |
| `visium-sandbox` | `Enforce-ALZ-Sandbox` → `SandboxDenyVnetPeering`, `SandboxNotAllowed` | — |

Public-network-access denies and the TLS/HTTPS baseline are therefore both in place.

`visium-corp` holds **zero subscriptions**; `visium-online` holds one, empty. Every
real workload sits in `visium-sandbox`, where public endpoints and IP forwarding are
allowed by design.


## Not enabled, and why

* **29 × `Enforce-GR-*`** — per-service guardrail initiatives whose parameters default
  to `Deny`. Corp and online are empty, so enabling them costs nothing today and each
  one becomes a plan review against live resources once a subscription lands.
* **`Enforce-GR-Storage0`** — `storageAccountSharedKey = Deny` blocks account-key auth.
  The Pulumi CD workflows in `VisiumCH/azure-infra` still call
  `az storage account keys list` against `stpulumistate0`. Blocked on
  [AZU-17](https://linear.app/visium/issue/AZU-17/centralize-iac-terraform-and-pulumi-states).
  It also forces default-deny firewalls via `storageAccountNetworkRules = Deny`.
* **`Enforce-Encrypt-CMK0`** — needs a Key Vault, key and identity per service.
* **`Enforce-Subnet-Private` at `Deny`** — rejects subnets keeping Azure's implicit
  outbound access. `azurerm` and `azure-native` both default that to `true`, so `Deny`
  breaks naive subnet definitions. It is set to `Default` + `Audit` instead.


## Verify

```bash
for mg in visium visium-landing-zones visium-corp visium-online visium-sandbox; do
  echo "== $mg"
  az policy assignment list \
    --scope "/providers/Microsoft.Management/managementGroups/$mg" \
    --query "[].{name:name,enforce:enforcementMode}" -o tsv | sort
done
```

Compliance data lags an assignment change by up to ~30 minutes.

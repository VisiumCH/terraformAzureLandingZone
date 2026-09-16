# Policy enforcement audit

What actually blocks a deployment in the `visium` tree, verified live against the
tenant on 2026-09-15. Companion to [README-VISIUM.md](README-VISIUM.md).

Library: `platform/alz` **2026.04.2**. All policy definitions and initiatives are
deployed once at the **`visium`** root MG; assignments reference them from any
descendant MG. That is why a policy can be assigned at `visium-online` even though the
upstream `online` archetype ships empty.

---

## Deny is blocking, not audit-first

The repo previously claimed deny policies started "non-blocking (audit /
DoNotEnforce)". That was false. The ALZ library ships every `Deny-*` assignment at
`enforcementMode: Default` — blocking — and it was never overridden.

What ALZ ships **off** (`DoNotEnforce`) is a different family: the 30 `Enforce-GR-*`
per-service guardrail initiatives, plus `Enforce-Subnet-Private` and
`Enforce-Encrypt-CMK0`, at both `visium-landing-zones` and `visium-platform`.

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

## Nothing is behind them yet

`visium-corp` holds **zero subscriptions**; `visium-online` holds one, empty. Every
real workload sits in `visium-sandbox`, where public endpoints and IP forwarding are
allowed by design.

```
visium-sandbox   Centris Dev · Visium Labs · Labs Demo/Staging · Visium Consulting
                 · Dataplatform Demo · MCPP · Microsoft Partner Network · Marion · Noe
                 └── customer-demo   4 × customer-demo-* subs
visium-corp      (empty)
visium-online    sub-visium-online (empty)
visium-platform  sub-visium-management
```

So "no public endpoints" blocks nothing today. Getting workloads into `visium-corp` is
onboarding work (AZU-11), deliberately not part of this audit — accepted by Anhelina on
2026-09-16.

Engineers write free-form Terraform or Pulumi in their own projects; there is no module
catalogue making workloads private by construction. Azure Policy is the only guardrail,
and the first project placed in corp will hit `Deny-Public-Endpoints` immediately.

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

## Other sharp edges

* `Deny-Public-Endpoints` covers 45 services — 43 of its 45 parameters default to
  `Deny` (exceptions: API Management, managed disks). A project without private
  endpoints cannot deploy into corp at all. See [ONBOARDING.md](ONBOARDING.md) §4.
* Deny never touches existing resources. Moving a subscription into corp breaks the
  *next* violating deployment, not what is running. ARG-scan before moving.
* Policy governs *what*; RBAC governs *who*. Blocking portal deployments is RBAC work
  (humans → Reader, writes via the OIDC deploy SP), tracked under AZU-9.

## Exceptions

Scoped policy exemptions, category `Waiver`, at subscription scope, referencing the
MG-level assignment id. Time-box with `--expires-on` where possible.

```bash
az policy exemption create \
  --name <project>-<what> \
  --policy-assignment-id /providers/Microsoft.Management/managementGroups/visium-corp/providers/Microsoft.Authorization/policyAssignments/Deny-Public-Endpoints \
  --exemption-category Waiver \
  --scope /subscriptions/<SUB_ID> \
  --description "<why, who approved, when it goes away>"
```

For an initiative, narrow with `--policy-definition-reference-ids` rather than waiving
all 45 rules.

### Live exemptions

| Name | Scope | Assignment | Rules | Expires |
|---|---|---|---|---|
| `customer-demo-networking` | MG `customer-demo` | `Enforce-ALZ-Sandbox` | `SandboxDenyVnetPeering`, `SandboxNotAllowed` | none — temp MG |
| `consulting-sandbox-peering` | sub `f12e214d` | `Enforce-ALZ-Sandbox` | `SandboxDenyVnetPeering` | none |
| `dp-sandbox-networking` | sub `8bec8b7e` | `Enforce-ALZ-Sandbox` | 2 rules | none |

None at `visium`, `visium-corp` or `visium-landing-zones`. `dp-sandbox-networking` was
believed deleted when the Dataplatform sub was reclassified to sandbox; it is still
present and inert.

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

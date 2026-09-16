# Onboarding a new project to Azure

How a new project, test setup, or client engagement gets an Azure home in the `visium`
landing zone.

The rule is **one landing zone (subscription or RG) per real project, with a named owner and a
budget** — so we always know who owns what, who to call when something breaks, and where
the money goes. Anything smaller than a real project (a test, a POC, a spike) does **not**
get its own subscription: it goes into the shared **Visium Consulting** subscription.

---

## 1. The model

```
visium
├── visium-landing-zones
│   ├── visium-corp     ── internal / client projects        (IaC-only, deny policies enforced)
│   └── visium-online   ── product / external-facing         (permissive carve-out)
└── visium-sandbox      ── experiments, POCs, test setups    (manual allowed, public-resource alerts)
    └── Visium Consulting sub — the shared home for anything that does NOT need its own sub
```

* **Sandbox / Visium Consulting** — quick tests and throwaway work. Manual portal creation
  is allowed, but creating a **public** resource fires a Slack alert in
  `#feed-infra-alerts`. Nothing here is production.
* **Corp / Online** — real projects. **The portal is read-only; all changes go through IaC**
  (Terraform or Pulumi via GitHub Actions). Deny policies are enforced.

## 2. Which path? — do you need your own subscription?

| The request is… | Home | Own subscription? |
|---|---|---|
| A quick experiment, POC, spike, or test setup — throwaway | **Visium Consulting** sub (sandbox tier) | **No** — a resource group in the shared sub |
| A real internal or client project that will live on | **visium-corp** | **Yes** — new subscription, named owner |
| A product / external-facing workload, or credit burn | **visium-online** | **Yes** — new subscription, named owner |

Rule of thumb: **if it will outlive a sprint, or hold anything worth protecting, it gets
its own subscription.** If in doubt, start in Visium Consulting and graduate it later.

## 3. How to request

If you definitely need a new Azure subscription then post in the **`#it-support`** Slack channel. A request needs:

A request needs:

| **Field** | **Notes** |
| --- | --- |
| Project name + one-line description | What it is, and for whom |
| Workload | `production-internal` or `production-external`  |
| **Owner** | A named person, not a team |
| Expected monthly budget + cost-center | Drives the budget + chargeback tags |
| Region(s) | Default **Switzerland North**; **Sweden Central** for GPU/LLM |
| Private connectivity needed? | Hub attach / access via **Tailscale** |
| Expected lifetime | Throwaway, project-length, or permanent |

Then:

1. **Platform team reviews** — confirms the path, the owner, and the budget.
2. **Provisioning**
   * *Resource group in Visium Consulting:* self-serve — the owner creates it, tagged.
   * *New subscription:* the platform team creates it on the Visium SA MCA billing profile,
     places it under the right management group, and assigns the owner the scoped custom
     `Subscription-Owner` role (owner rights on **their** subscription only, not tree-wide).
3. **Handover** — the tagging and policy baseline are already applied by inheritance, and a
   monthly budget + cost alert is set on the subscription.

## 4. What every landing zone gets automatically

* **Mandatory tags**, inherited from the resource group by policy — `project`,
  `cost-center`, `environment`, `owner` (`platform/main.tagging.tf`). Today these are
  *added* if missing (Modify, non-blocking). **Roadmap: enforce** — block creation of
  untagged resources so an owner is always attached (ties to
  [AZU-11](https://linear.app/visium/issue/AZU-11/33-define-ownership-per-workload-category)).
* **A monthly budget + cost alerts** (`platform/main.budgets.tf`) — default **500/month**,
  overridable per subscription. Notifies at **50 / 80 / 100 %** of actual spend, plus
  **100 % of forecast** as an early warning, into `#feed-infra-alerts` via the shared
  action group. A budget **caps nothing** — it makes spend visible.
* **Policy baseline** from the parent management group — full matrix in
  [POLICY.md](POLICY.md):
  * *Corp:* deny policies are **blocking, today**. `Deny-Public-Endpoints` covers **45
    PaaS services** — storage, Key Vault, SQL, Cosmos, AKS, ACR, OpenAI, ML, Container
    Apps, Event Hub, Service Bus, Synapse and more. **Plan for private endpoints from
    the first line of your IaC**: a workload that reaches its data services over public
    network access will not deploy into corp at all. Also enforced: NSG on every
    subnet, HTTPS/TLS only, no unmanaged disks, no public IP on a NIC, no
    hybrid-networking resources. Exceptions need a scoped, time-boxed policy
    **exemption** — ask in `#it-support` before you build around one.
  * *Online:* permissive product carve-out. Public endpoints are **audited, not
    blocked** — you'll show up on the compliance report, but nothing stops you.
  * *Sandbox / Consulting:* permissive, but **public-resource creation triggers a Slack
    alert** (`platform/main.alerting.tf`).
* **IaC-only enforcement** (corp / online) — the portal is read-only; deployments run
  through the GitHub Actions identity (Terraform / Pulumi). Manual changes are blocked.
* **Private-by-default networking** — access via **Tailscale**; no public exposure without
  a documented reason. Two-region hub: `vnet-hub-switzerlandnorth` (172.16.0.0/22) and
  `vnet-hub-swedencentral` (172.17.0.0/22).

## 5. Offboarding

**The owner named on the request owns the cleanup.** A landing zone is not finished when the project stops being interesting; it is finished when its resources are gone.

### **What to do**

| You are closing down… | Do this |
| --- | --- |
| A **resource group** in Visium Consulting | Delete the resource group — that removes everything inside it. If it was deployed with IaC, run `terraform destroy` / `pulumi destroy` first so state and reality stay in sync. |
| A **whole subscription** (corp / online) | Post in **`#it-support`**. The platform team tears down the workload, removes the budget and role assignments, and moves the subscription to the **`visium-decommissioned`** management group before cancellation. Do not cancel it yourself - it is on the shared billing profile. |
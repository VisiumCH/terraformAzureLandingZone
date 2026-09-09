# Onboarding a new project to Azure

How a new project, test setup, or client engagement gets an Azure home in the `visium`
landing zone.

The rule is **one landing zone (subscription) per real project, with a named owner and a
budget** — so we always know who owns what, who to call when something breaks, and where
the money goes. Anything smaller than a real project (a test, a POC, a spike) does **not**
get its own subscription: it goes into the shared **Visium Consulting** subscription.

> **Why this exists.** Historically a few subscriptions (Visium Consulting, Visium Labs)
> each held many unrelated projects. Nobody could say who owned a given resource or
> whether it was safe to delete, and cost drifted unnoticed. Every new project now starts
> as an owned, tagged, budgeted landing zone.

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
  `#visium-infra-alerts`. Nothing here is production.
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

Post in the **`#it-support`** Slack channel. A request needs:

| Field | Notes |
|---|---|
| Project name + one-line description | What it is, and for whom |
| **Owner** | A named person, not a team |
| Path | Consulting RG / corp sub / online sub (see §2) |
| Expected monthly budget + cost-center | Drives the budget + chargeback tags |
| Region(s) | Default **Switzerland North**; **Sweden Central** for GPU/LLM or DR |
| Private connectivity needed? | Hub attach / access via **Tailscale** |
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
  **100 % of forecast** as an early warning, into `#visium-infra-alerts` via the shared
  action group. A budget **caps nothing** — it makes spend visible.
* **Policy baseline** from the parent management group:
  * *Corp / Online:* deny policies **enforced** (no public endpoints unless justified, NSGs
    required, no unmanaged disks, …). Exceptions need a scoped, time-boxed policy
    **exemption**.
  * *Sandbox / Consulting:* permissive, but **public-resource creation triggers a Slack
    alert** (`platform/main.alerting.tf`).
* **IaC-only enforcement** (corp / online) — the portal is read-only; deployments run
  through the GitHub Actions identity (Terraform / Pulumi). Manual changes are blocked.
* **Private-by-default networking** — access via **Tailscale**; no public exposure without
  a documented reason. Two-region hub: `vnet-hub-switzerlandnorth` (172.16.0.0/22) and
  `vnet-hub-swedencentral` (172.17.0.0/22).

# Visium Platform Landing Zone — what to edit

This is the official Azure `platform_landing_zone` Terraform module. Treat almost all
of it as read-only vendored code (like node_modules). You only ever edit TWO files:

1. `management.tfvars`
     → region, subscriptions, subscription placement, policy settings.
2. `lib/architecture_definitions/visium.alz_architecture_definition.yaml`
     → which management groups exist / are adopted.

Everything else (`main.*.tf`, `variables.*.tf`, `locals.tf`, `outputs.tf`, `modules/`,
the rest of `lib/`, `terraform.tf`) is the upstream module — do not edit; upgrade it by
replacing from https://github.com/Azure/alz-terraform-accelerator .

Note: the large `variables.connectivity.*.tf` files are unused while
`connectivity_type = "none"` but are required by the module and used in Phase 2 (networking).

`examples/` has been removed (reference-only). See SETUP.md for the run steps.

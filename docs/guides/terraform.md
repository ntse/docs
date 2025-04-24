---
title: Terraform Guidance
parent: Guides
---

# Terraform Guidance

Terraform code should follow the standard [code guidance](./code.md) in addition to the below principals.

### Repo Organization
As a general rule, we avoid monolithic Terraform state files. Break infrastructure into logical units and define each in its own _stack_ with its own state file.

This modular approach improves maintainability, makes changes easier to test and review, and avoids reduces the blast radius of mistakes and bugs.

### Naming conventions

Follow [HashiCorp’s naming conventions](https://developer.hashicorp.com/terraform/plugin/best-practices/naming).

Avoid using naming styles from other languages, such as `camelCase` or `PascalCase`. Keep all variable names, inputs, and outputs lowercase with underscores for consistency.

### Use positive variable names to avoid double negatives
To reduce confusion and ambiguity, avoid double negatives in variable names. Use names that express intent clearly. For example: `encryption_enabled`, not `disable_encryption`.

Default values can be either true or false, depending on what makes sense - just keep the naming intuitive.

### Use description field for all inputs and outputs
Every input and output variable should include a description — even when the meaning seems obvious.

If you're exposing a value from an upstream provider (like a Terraform AWS module), reuse the wording from their documentation to stay consistent.

### Provide Sensible Defaults
Modules should work with minimal setup. Where possible, provide secure and production-ready defaults — for example, default to encryption_enabled = true.

This makes modules safer to use and reduces onboarding time for new users.

### Always Use Remote State
State stored on your laptop doesn't help your team. Use remote state backends — like S3 or Azure Storage — so the state is shared, versioned, and protected.

To do this, follow a two-phase approach:

- Create the backend storage (S3, Azure, etc.) without remote state enabled.
- Configure backend {} in your Terraform code and run terraform init to migrate to remote state.

Refer to our guides for setup instructions:

- [AWS Backend Guide](https://github.com/ukhsa-collaboration/devops-terraform-modules/blob/main/terraform-modules/aws/state-file/USAGE.MD)
- [Azure Backend Guide](https://github.com/ukhsa-collaboration/devops-terraform-modules/blob/main/terraform-modules/azure/state-file/USAGE.md)

### Set variable values once
The values of your variables should only be set once to avoid confusion. E.g. don't set the same variables in `environments/dev.tfvars` and `core-services/network/tfvars/dev.tfvars` as it's not immediately obvious which value actually has an effect.

### Secure your state file
Terraform state files can contain secrets and sensitive data. Protect them accordingly:

- Enable encryption
- Enable versioning
- Apply strict IAM policies

This ensures you can recover from accidental deletions and keep sensitive infrastructure data safe.

## Repo Organisation - FAQ

### How should I organise my Terraform stacks?
There’s no one-size-fits-all approach to organising Terraform stacks. The goal is to strike a balance between reducing blast radius and keeping tightly coupled resources in the same stack to allow Terraform to manage dependencies more effectively.

In general, try to group related infrastructure (e.g. networking, compute, storage) into standalone stacks, isolate application deployments into their own stacks (e.g. frontend, backend) unless they are very tightly coupled and avoid creating overly granular stacks that add complexity without meaningful isolation benefits.
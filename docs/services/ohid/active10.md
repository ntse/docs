---
title: Active10
parent: OHID
---

# Active10

Active10 is a mobile app used to anonymously record every minute of walking that a user does by tracking their steps. The mobile app connects to the API which consists of a loadbalancer, an ECS cluster and an RDS database cluster.
---

## Architecture Overview

- **Application Load Balancer (ALB)** → **ECS (Fargate)** → **Postgres (RDS)**

---

## Components

### Application

- **Repo:** [talk-to-frank (Next.js app)](https://github.com/ukhsa-collaboration/active10-backend)
- The frontend application built with Next.js.

### Infrastructure as Code (IaC)

- **Repo:** [active10-infra](https://github.com/ukhsa-collaboration/active10-infra)
- Terraform code defining AWS infrastructure for all environments.

---

## Environments

| Environment | URL                                 | Notes |
|-------------|-------------------------------------|-------|
| **Production** | https://prd.active10.betterhealthapps.com/    | Protected by manual GitHub approval before deploy |
| **Staging**     | https://uat.active10.betterhealthapps.com/   | Auto-deploys |
| **Preview**     | https://dev.active10.betterhealthapps.com/   | First environment for testing new code |

---
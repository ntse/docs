---
title: Talk to Frank
parent: OHID
---

# Talk to Frank

Talk to Frank is a public-facing website offering drug advice for children and adults. It is deployed on AWS using ECS, behind a CloudFront distribution and an ALB, which routes traffic to ECS containers.

The site integrates with AWS OpenSearch (formerly Elasticsearch) to power its drug search functionality. The frontend uses the headless CMS [Contentful](https://www.contentful.com/) for its backend.

---

## Architecture Overview

- **CloudFront** → **Application Load Balancer (ALB)** → **ECS (Fargate)** → **AWS OpenSearch**

---

## Components

### Application

- **Repo:** [talk-to-frank (Next.js app)](https://github.com/ukhsa-collaboration/talk-to-frank)
- The frontend application built with Next.js.

### Infrastructure as Code (IaC)

- **Repo:** [talk-to-frank-iac](https://github.com/ukhsa-collaboration/talk-to-frank-iac)
- Terraform code defining AWS infrastructure for all environments.

---

## Environments

| Environment | URL                                 | Notes |
|-------------|-------------------------------------|-------|
| **Production** | https://www.talktofrank.com        | Protected by manual GitHub approval before deploy |
| **Staging**     | https://staging.talktofrank.com   | Auto-deploys if preview tests pass |
| **Preview**     | https://preview.talktofrank.com   | First environment for testing new code |

---
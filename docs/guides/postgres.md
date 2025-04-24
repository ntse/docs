---
title: Postgres
parent: Guides
---

# Postgres

## Provisioning

To provision Postgres databases, I currently connect to the database instance manually using the [port forwarding script](../../scripts/port_forward.sh). This creates a tunnel, allowing local access to the instance via `localhost:5432`.

Once connected, I manually create the database and run the [Postgres bootstrap script](../../scripts/postgres_bootstrap.py). This script grants all users full permissions on the database. While it works for initial setup, it's overly permissive. Long term, we should grant least privilege permissions tailored to each user and define users and permissions in code to improve reproducibility and auditability.

## Port Forwarding

The port forwarding script connects to the Bastion host in the same VPC as the Postgres instance, then tunnels traffic to the database.

In the future, I'd like to replace this with [AWS Session Manager](https://aws.amazon.com/blogs/database/securely-connect-to-amazon-rds-for-postgresql-with-aws-session-manager-and-iam-authentication/) for more secure, auditable access, but haven't yet tested this in Halo-provisioned accounts.

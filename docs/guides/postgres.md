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

## Database Access

To connect to a Postgres database running in AWS, follow the steps below.

### Prerequisites

1. Authenticate with AWS
   Make sure you're authenticated using your own AWS CLI credentials.

   If needed, refer to [aws-vault setup](./aws-vault.md) for secure credential management.

2. Ensure Postgres is not running locally

   Port `5432` is used for the port-forwarding tunnel. If a local instance of Postgres is running, it will block the tunnel setup.

   You can check this with:

   ```bash
   lsof -i :5432
   ```

   If something is using the port, stop the local Postgres service or change its port temporarily.

3. Bastion Server
   This script relies on a Bastion server existing with connectivity to the database instance.


### Running the Port Forwarding Script

Run the [port_foward.sh script](../../scripts/port_forward.sh). This will:

- Generate a temporary SSH key and authorize it
- Authorise your current IP address to access the Bastion host
- Open an SSH tunnel from local port 5432 to the Aurora writer endpoint
- Start an SSH session (you need to keep this terminal open whilst using Postgres)

```bash
./port_forward.sh --project active10
```

### Connecting to the Database
While the SSH session is running, you can connect to the database from a separate terminal using tools like psql or pgAdmin.

Example using psql
```bash
psql -h localhost -U root postgres
```

### Common errors

#### Port 5432 is already in use
If you see this error:

```Error: Port 5432 is already in use. Please check that Postgres is not already running.```

Run:
```bash
lsof -i :5432
```

Then stop the process that is using the port. For example:
```bash
brew services stop postgresql
```

Or, if you need to keep it running, change the port your local Postgres is using and restart the service.

#### SSH connection times out or fails

- Confirm that your IP address is correctly retrieved by the script (check MY_IP output).
- Check your network/firewall settings if you're behind a corporate VPN.
- Ensure the Bastion instance is running and reachable via aws ec2 describe-instances.
- Ensure that the Bastion instance can actually reach the database. You can verify this by manually connecting to the Bastion and running a `cURL` command against the database endpoint on port 5432.

#### Invalid Postgres credentials
If you receive an authentication error in psql:

- Ensure you're using the credentials printed by the script.
- If connecting via pgAdmin, double-check you're not storing an old password.

#### Invalid AWS credentials
If you get an error like:

```
Error: Could not retrieve Bastion instance details.
```

or

This could be because you're not authorised to view the AWS instance details. Ensure that you're using the expected AWS role and IAM user by running:

```bash
aws sts get-caller-identity
```

Your STS session may have timed out (1 hour for aws-vault by default, 24 hours for Halo-provisioned accounts) so you may need to authenticate.

#### Cannot find Bastion server
If you get an error like:

```
Parameter validation failed:
Invalid length for parameter InstanceId, value: 4, valid min length: 10
```

Ensure that you have a bastion server in the account that you're connecting to that follows the naming pattern `aw-${PROJECT}-*-ec2-bastion`
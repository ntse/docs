#!/bin/bash
set -euo pipefail

# Change this to your project short name
PROJECT=prj

SSH_KEY=/tmp/temporary_key.$RANDOM
trap 'rm -f ${SSH_KEY} ${SSH_KEY}.pub' EXIT

ssh-keygen -t rsa -N "" -f "$SSH_KEY" -q

if lsof -i:5432 >/dev/null; then
  echo "Error: Port 5432 is already in use. Please check that Postgres is not already running."
  exit 1
fi

MY_IP=$(curl --silent --fail -4 ifconfig.me)
if [[ -z "$MY_IP" ]]; then
  echo "Error: Failed to retrieve public IP."
  exit 1
fi

INSTANCE_JSON=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=aw-$PROJECT-euw2-*-ec2-bastion" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0]' \
  --output json)

INSTANCE_ID=$(echo "$INSTANCE_JSON" | jq -r '.InstanceId')
PUBLIC_IP=$(echo "$INSTANCE_JSON" | jq -r '.PublicIpAddress')

if [[ -z "$INSTANCE_ID" || -z "$PUBLIC_IP" ]]; then
  echo "Error: Could not retrieve Bastion instance details."
  exit 1
fi

AURORA_WRITER_ENDPOINT=$(aws rds describe-db-cluster-endpoints \
  --filters "Name=db-cluster-endpoint-type,Values=writer" \
  --query 'DBClusterEndpoints[0].Endpoint' \
  --output text 2>/dev/null || echo "")

DB_DETAILS_JSON=$(aws rds describe-db-clusters --query 'DBClusters[0]' --output json)

DB_USERNAME=$(echo "$DB_DETAILS_JSON" | jq -r '.MasterUsername')
DB_PASSWORD_SECRET=$(echo "$DB_DETAILS_JSON" | jq -r '.MasterUserSecret.SecretArn')

if [[ -z "$AURORA_WRITER_ENDPOINT" || -z "$DB_USERNAME" || -z "$DB_PASSWORD_SECRET" ]]; then
  echo "Error: Failed to retrieve database details."
  exit 1
fi

DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_PASSWORD_SECRET" --query SecretString --output text | jq -r '.password')

if [[ -z "$DB_PASSWORD" ]]; then
  echo "Error: Failed to retrieve database password."
  exit 1
fi

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*-sg-bastion" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || echo "")

if [[ -z "$SECURITY_GROUP_ID" ]]; then
  echo "Error: Could not retrieve Security Group ID."
  exit 1
fi

aws ec2-instance-connect send-ssh-public-key \
  --instance-id "$INSTANCE_ID" \
  --instance-os-user ec2-user \
  --ssh-public-key "file://${SSH_KEY}.pub"

aws ec2 authorize-security-group-ingress \
  --group-id "$SECURITY_GROUP_ID" \
  --protocol tcp --port 22 --cidr "${MY_IP}/32" 2>/dev/null || true

echo "######################## USE THE DETAILS BELOW TO AUTHENTICATE TO POSTGRES ########################"
echo
echo "You can now connect to Postgres using these credentials:"
echo "Host: localhost:5432"
echo "Username: $DB_USERNAME"
echo "Password: $DB_PASSWORD"
echo
echo "######################## USE THE DETAILS ABOVE TO AUTHENTICATE TO POSTGRES ########################"

ssh -o StrictHostKeyChecking=no -L 5432:"$AURORA_WRITER_ENDPOINT":5432 -i "$SSH_KEY" ec2-user@"$PUBLIC_IP"
 

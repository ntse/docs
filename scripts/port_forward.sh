#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 --project <project-short-name> [--region <aws-region>]"
  exit 1
}

PROJECT=""
REGION="${AWS_REGION:-eu-west-2}"
PORT=5432
SSH_USER="ec2-user"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [[ -z "$PROJECT" ]]; then
  echo "Error: --project is required"
  usage
fi

SSH_KEY=$(mktemp /tmp/temporary_key.XXXXXX)
trap 'rm -f "${SSH_KEY}" "${SSH_KEY}.pub"' EXIT

ssh-keygen -t rsa -N "" -f "$SSH_KEY" -q

if lsof -i:$PORT >/dev/null; then
  echo "Error: Port $PORT is already in use. Please check that Postgres is not already running."
  exit 1
fi

MY_IP=$(curl --silent --fail -4 ifconfig.me || true)
if [[ -z "$MY_IP" ]]; then
  echo "Error: Failed to retrieve public IP."
  exit 1
fi

INSTANCE_JSON=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=aw-${PROJECT}-*-ec2-bastion" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0]' \
  --output json)

INSTANCE_ID=$(echo "$INSTANCE_JSON" | jq -r '.InstanceId')
PUBLIC_IP=$(echo "$INSTANCE_JSON" | jq -r '.PublicIpAddress')

if [[ -z "$INSTANCE_ID" || -z "$PUBLIC_IP" ]]; then
  echo "Error: Could not retrieve Bastion instance details."
  exit 1
fi

AURORA_WRITER_ENDPOINT=$(aws rds describe-db-cluster-endpoints \
  --region "$REGION" \
  --filters "Name=db-cluster-endpoint-type,Values=writer" \
  --query 'DBClusterEndpoints[0].Endpoint' \
  --output text 2>/dev/null || echo "")

DB_DETAILS_JSON=$(aws rds describe-db-clusters \
  --region "$REGION" \
  --query 'DBClusters[0]' --output json)

DB_USERNAME=$(echo "$DB_DETAILS_JSON" | jq -r '.MasterUsername')
DB_PASSWORD_SECRET=$(echo "$DB_DETAILS_JSON" | jq -r '.MasterUserSecret.SecretArn')

if [[ -z "$AURORA_WRITER_ENDPOINT" || -z "$DB_USERNAME" || -z "$DB_PASSWORD_SECRET" ]]; then
  echo "Error: Failed to retrieve database details."
  exit 1
fi

DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "$DB_PASSWORD_SECRET" \
  --query SecretString --output text | jq -r '.password')

if [[ -z "$DB_PASSWORD" ]]; then
  echo "Error: Failed to retrieve database password."
  exit 1
fi

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=*${PROJECT}*-sg-bastion" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || echo "")

if [[ -z "$SECURITY_GROUP_ID" ]]; then
  echo "Error: Could not retrieve Security Group ID."
  exit 1
fi

aws ec2-instance-connect send-ssh-public-key \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID" \
  --instance-os-user "$SSH_USER" \
  --ssh-public-key "file://${SSH_KEY}.pub"

aws ec2 authorize-security-group-ingress \
  --region "$REGION" \
  --group-id "$SECURITY_GROUP_ID" \
  --protocol tcp --port 22 --cidr "${MY_IP}/32" 2>/dev/null || true

echo
echo "=============================================="
echo "Postgres Connection Details:"
echo "Host: localhost:$PORT"
echo "Username: $DB_USERNAME"
echo "Password: $DB_PASSWORD"
echo "=============================================="
echo

ssh -o StrictHostKeyChecking=no -L ${PORT}:"$AURORA_WRITER_ENDPOINT":5432 -i "$SSH_KEY" "$SSH_USER@$PUBLIC_IP"
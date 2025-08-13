#!/bin/bash
set -euo pipefail

# ----------------------------
# Launch (or reuse) a Free Tier EC2 instance
# - Reads SG ID from cloudlab_sg_id.txt (in current directory)
# - Uses key pair "cloudlab-key" (change via KEY_NAME env)
# - Tries t3.micro, falls back to t2.micro
# - Amazon Linux 2023 (x86_64) via SSM parameter
# - Saves instance ID and public IP to files in current dir
# ----------------------------

REGION=$(aws configure get region)
KEY_NAME="${KEY_NAME:-cloudlab-key}"
INSTANCE_NAME="${INSTANCE_NAME:-cloudlab-ec2}"

# ---- Inputs & sanity checks
if [[ ! -f cloudlab_sg_id.txt ]]; then
  echo "ERROR: cloudlab_sg_id.txt not found in current directory."
  echo "Run create_security_group.sh here first (or copy the file into this folder)."
  exit 1
fi
SG_ID="$(cat cloudlab_sg_id.txt)"

# Ensure key pair exists in this region
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "ERROR: Key pair \"$KEY_NAME\" not found in region $REGION."
  echo "Create it first, e.g.:"
  echo "  aws ec2 create-key-pair --region $REGION --key-name $KEY_NAME --key-type rsa --key-format pem --query 'KeyMaterial' --output text > ~/.ssh/${KEY_NAME}.pem"
  echo "  chmod 400 ~/.ssh/${KEY_NAME}.pem"
  exit 1
fi

# ---- Reuse existing instance if present (pending/running/stopping/stopped)
EXISTING_INFO=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[0].[InstanceId,State.Name,PublicIpAddress]' \
  --output text || true)

if [[ -n "$EXISTING_INFO" && "$EXISTING_INFO" != "None" ]]; then
  INSTANCE_ID=$(echo "$EXISTING_INFO" | awk '{print $1}')
  STATE=$(echo "$EXISTING_INFO" | awk '{print $2}')
  EXISTING_IP=$(echo "$EXISTING_INFO" | awk '{print $3}')

  echo "Found existing instance: $INSTANCE_ID (state: $STATE)"
  if [[ "$STATE" == "stopped" ]]; then
    echo "Starting instance..."
    aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$REGION" >/dev/null
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
  elif [[ "$STATE" == "stopping" || "$STATE" == "pending" ]]; then
    echo "Waiting for instance to become running..."
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
  fi

  # Refresh public IP
  PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
else
  # ---- Launch a fresh instance
  echo "Fetching latest Amazon Linux 2023 AMI (x86_64)..."
  AMI_ID=$(aws ssm get-parameters \
    --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64 \
    --region "$REGION" \
    --query 'Parameters[0].Value' --output text)

  echo "Launching instance with AMI $AMI_ID ..."
  # Try t3.micro (Free Tier), fall back to t2.micro if not available in account/region
  set +e
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Project,Value=CloudLab}]" \
    --region "$REGION" \
    --query 'Instances[0].InstanceId' --output text 2>/dev/null)
  RC=$?
  set -e
  if [[ $RC -ne 0 || -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
    echo "t3.micro failed in this region/account; trying t2.micro..."
    INSTANCE_ID=$(aws ec2 run-instances \
      --image-id "$AMI_ID" \
      --instance-type t2.micro \
      --key-name "$KEY_NAME" \
      --security-group-ids "$SG_ID" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Project,Value=CloudLab}]" \
      --region "$REGION" \
      --query 'Instances[0].InstanceId' --output text)
  fi

  echo "Instance launched: $INSTANCE_ID"
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

  PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
fi

# ---- Save outputs locally
echo "$INSTANCE_ID" > cloudlab_instance_id.txt
echo "$PUBLIC_IP" > cloudlab_public_ip.txt

echo "----------------------------------------"
echo "Instance ID : $INSTANCE_ID"
echo "Public IP   : $PUBLIC_IP"
echo "Region      : $REGION"
echo "SSH command : ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo "Saved to    : cloudlab_instance_id.txt, cloudlab_public_ip.txt"
echo "OS user     : ec2-user (Amazon Linux 2023)"
echo "----------------------------------------"


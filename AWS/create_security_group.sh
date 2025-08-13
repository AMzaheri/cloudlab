#!/bin/bash
#  Create a security group (allow SSH from your IP only)

set -euo pipefail

# ----------------------------
# Create or reuse a security group (allow SSH from your IP only)
# ----------------------------

REGION=$(aws configure get region)
SG_NAME="cloudlab-sg"

# Get your current public IP
MY_IP=$(curl -s https://checkip.amazonaws.com)

# Check if the security group already exists
EXISTING=$(aws ec2 describe-security-groups \
  --group-names "$SG_NAME" \
  --region "$REGION" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || true)

if [ "$EXISTING" != "None" ] && [ -n "$EXISTING" ]; then
    SG_ID="$EXISTING"
    echo "Using existing security group: $SG_ID"
else
    SG_ID=$(aws ec2 create-security-group \
      --group-name "$SG_NAME" \
      --description "Security group for CloudLab EC2" \
      --region "$REGION" \
      --query 'GroupId' \
      --output text)
    echo "Created new security group: $SG_ID"
fi

# Check if SSH rule already exists for this IP
HAVE_RULE=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --region "$REGION" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\` && ToPort==\`22\` && IpProtocol=='tcp' && IpRanges[?CidrIp=='${MY_IP}/32']]|length(@)")

if [ "$HAVE_RULE" -eq 0 ]; then
    aws ec2 authorize-security-group-ingress \
      --group-id "$SG_ID" \
      --protocol tcp \
      --port 22 \
      --cidr ${MY_IP}/32 \
      --region "$REGION"
    echo "Added SSH rule for ${MY_IP}/32"
else
    echo "SSH rule for ${MY_IP}/32 already exists"
fi

# Tag the security group for easier identification
aws ec2 create-tags \
  --resources "$SG_ID" \
  --tags Key=Project,Value=CloudLab Key=Owner,Value=Afsaneh \
  --region "$REGION"

# Save the SG ID for later scripts
echo "$SG_ID" > cloudlab_sg_id.txt
echo "Security Group ID saved to cloudlab_sg_id.txt"


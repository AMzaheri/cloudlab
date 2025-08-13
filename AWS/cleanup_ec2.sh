#!/bin/bash

# This script safely terminates your EC2 instance and then tries to delete the security group (it won’t error out if it’s still attached).

set -euo pipefail

# Terminate EC2 instance and (optionally) delete its security group.
# Safe to re-run: ignores missing files and handles already-terminated instances.

REGION=$(aws configure get region)
cd "$(dirname "$0")"

# --- Terminate instance if we have an ID file
if [[ -f cloudlab_instance_id.txt ]]; then
  INSTANCE_ID=$(cat cloudlab_instance_id.txt)
  echo "Terminating instance: $INSTANCE_ID ..."
  set +e
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION" >/dev/null 2>&1
  set -e
  # Wait (best-effort)
  aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$REGION" || true
  echo "Instance terminated (or was already terminated)."
else
  echo "No cloudlab_instance_id.txt found — skipping instance termination."
fi

# --- Try to delete the security group (best-effort)
if [[ -f cloudlab_sg_id.txt ]]; then
  SG_ID=$(cat cloudlab_sg_id.txt)
  echo "Attempting to delete security group: $SG_ID ..."
  set +e
  aws ec2 delete-security-group --group-id "$SG_ID" --region "$REGION"
  RC=$?
  set -e
  if [[ $RC -eq 0 ]]; then
    echo "Security group deleted."
    rm -f cloudlab_sg_id.txt
  else
    echo "Could not delete security group (maybe still attached or in use). Keeping it for reuse."
  fi
else
  echo "No cloudlab_sg_id.txt found — skipping security group deletion."
fi

# --- Clean up local tracking files
rm -f cloudlab_public_ip.txt cloudlab_instance_id.txt || true
echo "Cleanup complete."


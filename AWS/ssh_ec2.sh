#!/bin/bash

#A Helper script to SHH into EC2

set -euo pipefail

KEY_PATH="${KEY_PATH:-$HOME/.ssh/cloudlab-key.pem}"
IP_FILE="cloudlab_public_ip.txt"

if [[ ! -f "$IP_FILE" ]]; then
  echo "ERROR: $IP_FILE not found. Run launch_ec2.sh first (in this folder)."
  exit 1
fi

PUBLIC_IP=$(cat "$IP_FILE")
chmod 400 "$KEY_PATH" 2>/dev/null || true
echo "Connecting to ec2-user@$PUBLIC_IP ..."
exec ssh -i "$KEY_PATH" ec2-user@"$PUBLIC_IP"

#------------------------------------------
#Troubleshooting (quick):
# “UNPROTECTED PRIVATE KEY FILE!” → run: chmod 400 ~/.ssh/cloudlab-key.pem
#“Permission denied (publickey).”:
# Ensure user is ec2-user (Amazon Linux 2023).
# Confirm you used the correct key pair name/path.
#Timeout / hang:
# Your public IP may have changed; re‑run your security group script to add the new IP:
# ./create_security_group.sh (from cloudlab/AWS)
# Different region? Make sure your CLI region is the same one you launched in.

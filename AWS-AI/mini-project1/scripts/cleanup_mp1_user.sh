#!/usr/bin/env bash
set -euo pipefail

# Teardown for the mini-project IAM user and policy.
# Usage:
#   ./cleanup_mp1_user.sh --user cloudlab-mp1-user --policy-name CloudLabS3MiniProjAccess

USER_NAME="${USER_NAME:-cloudlab-mp1-user}"
POLICY_NAME="${POLICY_NAME:-CloudLabS3MiniProjAccess}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) USER_NAME="$2"; shift 2 ;;
    --policy-name) POLICY_NAME="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 --user <name> --policy-name <name>"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "[INFO] Detach policy from user (if attached)…"
set +e
aws iam detach-user-policy --user-name "${USER_NAME}" --policy-arn "${POLICY_ARN}" 2>/dev/null
set -e

echo "[INFO] Delete access keys (if any)…"
KEY_IDS=$(aws iam list-access-keys --user-name "${USER_NAME}" --query 'AccessKeyMetadata[].AccessKeyId' --output text || true)
for K in $KEY_IDS; do
  aws iam delete-access-key --user-name "${USER_NAME}" --access-key-id "$K"
done

echo "[INFO] Delete user (if exists)…"
aws iam delete-user --user-name "${USER_NAME}" 2>/dev/null || echo "[WARN] User may not exist."

echo "[INFO] Delete managed policy (versions must be cleaned first)…"
# Delete non-default versions
VERS=$(aws iam list-policy-versions --policy-arn "${POLICY_ARN}" --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text 2>/dev/null || true)
for V in $VERS; do
  aws iam delete-policy-version --policy-arn "${POLICY_ARN}" --version-id "$V" || true
done
aws iam delete-policy --policy-arn "${POLICY_ARN}" 2>/dev/null || echo "[WARN] Policy may not exist."

echo "[Done] Cleanup complete."


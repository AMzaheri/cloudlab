#!/usr/bin/env bash
set -euo pipefail

# Minimal, least-privilege setup for the S3 mini-project.
# Creates (or reuses) a bucket, a managed IAM policy scoped to a prefix,
# a dedicated IAM user, and attaches the policy to that user.
#
# Defaults are safe; override via env vars or flags.
#
# Usage:
#   ./setup_mp1_user.sh \
#     --bucket your-unique-bucket \
#     --prefix aws-ai/mini-project1 \
#     --region eu-west-2 \
#     --user cloudlab-mp1-user \
#     --policy-name CloudLabS3MiniProjAccess
#
# After running, (optionally) create an access key MANUALLY:
#   aws iam create-access-key --user-name cloudlab-mp1-user
# Then configure a profile:
#   aws configure --profile mp1
#
# And run s3_etl.py with:
#   AWS_PROFILE=mp1 python s3_etl.py --bucket your-unique-bucket --region eu-west-2 --key-prefix aws-ai/mini-project1 --local-csv data/sample.csv

# ---------- defaults ----------
BUCKET="${BUCKET:-}"
PREFIX="${PREFIX:-aws-ai/mini-project1}"
REGION="${REGION:-eu-west-2}"
USER_NAME="${USER_NAME:-cloudlab-mp1-user}"
POLICY_NAME="${POLICY_NAME:-CloudLabS3MiniProjAccess}"

# ---------- tiny arg parser ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket) BUCKET="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --policy-name) POLICY_NAME="$2"; shift 2 ;;
    -h|--help)
      grep '^# ' "$0" | sed 's/^# //'; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "${BUCKET}" ]]; then
  echo "ERROR: --bucket is required (bucket names are global)."
  exit 1
fi

echo "== Config =="
echo "Region:       ${REGION}"
echo "Bucket:       ${BUCKET}"
echo "Prefix:       ${PREFIX}"
echo "IAM User:     ${USER_NAME}"
echo "Policy Name:  ${POLICY_NAME}"
echo

# ---------- create bucket if needed ----------
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "[OK] Bucket exists: s3://${BUCKET}"
else
  echo "[CREATE] Bucket s3://${BUCKET} (region ${REGION})"
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --create-bucket-configuration LocationConstraint="${REGION}" \
    --region "${REGION}"
fi

# ---------- build policy JSON (least privilege) ----------
TMP_POLICY_JSON="$(mktemp)"
cat > "$TMP_POLICY_JSON" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucketUnderPrefix",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::${BUCKET}"],
      "Condition": { "StringLike": { "s3:prefix": ["${PREFIX}/*"] } }
    },
    {
      "Sid": "ObjectRWForPrefix",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::${BUCKET}/${PREFIX}/*"]
    }
  ]
}
JSON

# ---------- create or reuse managed policy ----------
POLICY_ARN=""
if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/${POLICY_NAME}" >/dev/null 2>&1; then
  POLICY_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/${POLICY_NAME}"
  echo "[OK] Policy exists: ${POLICY_ARN}"
else
  echo "[CREATE] Managed policy: ${POLICY_NAME}"
  POLICY_ARN="$(aws iam create-policy \
    --policy-name "${POLICY_NAME}" \
    --policy-document "file://${TMP_POLICY_JSON}" \
    --query 'Policy.Arn' --output text)"
  echo "[OK] Created policy ARN: ${POLICY_ARN}"
fi

# ---------- create or reuse IAM user ----------
if aws iam get-user --user-name "${USER_NAME}" >/dev/null 2>&1; then
  echo "[OK] User exists: ${USER_NAME}"
else
  echo "[CREATE] User: ${USER_NAME}"
  aws iam create-user --user-name "${USER_NAME}" >/dev/null
fi

# ---------- attach policy to user (idempotent) ----------
if aws iam list-attached-user-policies --user-name "${USER_NAME}" \
   --query "AttachedPolicies[?PolicyArn=='${POLICY_ARN}'] | length(@)" --output text | grep -q '^1$'; then
  echo "[OK] Policy already attached to user."
else
  echo "[ATTACH] ${POLICY_NAME} → ${USER_NAME}"
  aws iam attach-user-policy --user-name "${USER_NAME}" --policy-arn "${POLICY_ARN}"
fi

echo
echo "== Next steps =="
echo "1) (Optional) Create an access key MANUALLY (do not script this to avoid secrets in logs):"
echo "   aws iam create-access-key --user-name ${USER_NAME}"
echo "   # then: aws configure --profile mp1   (region: ${REGION}, output: json)"
echo "2) Run ETL using that profile:"
echo "   AWS_PROFILE=mp1 python s3_etl.py --bucket ${BUCKET} --region ${REGION} --key-prefix ${PREFIX} --local-csv data/sample.csv"
echo
echo "[Done] Least-privilege user setup complete."


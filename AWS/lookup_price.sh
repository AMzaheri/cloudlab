#!/bin/bash
set -euo pipefail

# Look up EC2 On-Demand price via AWS Pricing API
# Usage:
#   ./lookup_price.sh <instance_type> [location] [os]
# Examples:
#   ./lookup_price.sh t3.micro
#   ./lookup_price.sh t3.micro "EU (London)"
#   ./lookup_price.sh t3.micro "EU (London)" Linux
#
# Notes:
# - Pricing API endpoint is us-east-1 regardless of your resource region.
# - Requires: aws cli, jq

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <instance_type> [location] [os]"
  echo "Default location: EU (London)"
  echo "Default OS: Linux"
  exit 1
fi

INSTANCE_TYPE="$1"
LOCATION="${2:-EU (London)}"
OS="${3:-Linux}"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: 'jq' is required. Install with 'brew install jq' (macOS) or your package manager."
  exit 1
fi

# Query AWS Pricing API. We filter for common On-Demand Linux, Shared tenancy, no preinstalled software.
RAW=$(
  aws pricing get-products \
    --region us-east-1 \
    --service-code AmazonEC2 \
    --filters \
      "Type=TERM_MATCH,Field=instanceType,Value=${INSTANCE_TYPE}" \
      "Type=TERM_MATCH,Field=location,Value=${LOCATION}" \
      "Type=TERM_MATCH,Field=operatingSystem,Value=${OS}" \
      "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
      "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
      "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
    --query 'PriceList[0]' \
    --output text
)

if [[ -z "${RAW}" || "${RAW}" == "None" ]]; then
  echo "No price found for: ${INSTANCE_TYPE} / ${OS} / ${LOCATION}"
  exit 2
fi

# 'RAW' is a JSON string; parse it to get USD hourly price from OnDemand terms.
PRICE=$(echo "${RAW}" | jq -r '
  .terms.OnDemand
  | to_entries[0].value.priceDimensions
  | to_entries[0].value.pricePerUnit.USD
')

UNIT=$(echo "${RAW}" | jq -r '
  .terms.OnDemand
  | to_entries[0].value.priceDimensions
  | to_entries[0].value.unit
')

# Fallback if unit is missing
UNIT=${UNIT:-Hrs}

# Compute an estimated monthly cost assuming 750 hours (Free Tier comparison)
MONTHLY=$(awk -v p="${PRICE}" 'BEGIN { printf "%.4f", p * 750 }')

echo "EC2 On-Demand Price:"
echo "  Instance type : ${INSTANCE_TYPE}"
echo "  Location      : ${LOCATION}"
echo "  OS            : ${OS}"
echo "  Tenancy       : Shared"
echo "  Price         : USD ${PRICE} per ${UNIT}"
echo "  ~750 hrs/mo   : USD ${MONTHLY} (estimate)"


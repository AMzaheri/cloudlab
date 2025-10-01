# 1. Delete all SageMaker endpoints (and their configs & models)
# List all endpoint names
ENDPOINTS=$(aws sagemaker list-endpoints --region "$AWS_REGION" \
  --query 'Endpoints[].EndpointName' --output text)

for EP in $ENDPOINTS; do
  echo "Deleting endpoint: $EP"
  EP_CONFIG=$(aws sagemaker describe-endpoint --endpoint-name "$EP" --region "$AWS_REGION" \
    --query 'EndpointConfigName' --output text 2>/dev/null || echo "")

  aws sagemaker delete-endpoint --endpoint-name "$EP" --region "$AWS_REGION" || true

  if [ -n "$EP_CONFIG" ] && [ "$EP_CONFIG" != "None" ]; then
    echo "Deleting endpoint-config: $EP_CONFIG"
    MODELS=$(aws sagemaker describe-endpoint-config --endpoint-config-name "$EP_CONFIG" \
      --region "$AWS_REGION" --query 'ProductionVariants[].ModelName' --output text 2>/dev/null || echo "")
    aws sagemaker delete-endpoint-config --endpoint-config-name "$EP_CONFIG" --region "$AWS_REGION" || true

    for M in $MODELS; do
      [ -n "$M" ] && echo "Deleting model: $M" \
        && aws sagemaker delete-model --model-name "$M" --region "$AWS_REGION" || true
    done
  fi
done


# 2) Delete any stray models that aren’t tied to an endpoint
for M in $(aws sagemaker list-models --region "$AWS_REGION" --query 'Models[].ModelName' --output text); do
  echo "Deleting leftover model: $M"
  aws sagemaker delete-model --model-name "$M" --region "$AWS_REGION" || true
done

# 3) Delete CloudWatch log groups for endpoints
for LG in $(aws logs describe-log-groups \
  --log-group-name-prefix "/aws/sagemaker/Endpoints/" \
  --region "$AWS_REGION" --query 'logGroups[].logGroupName' --output text); do
  echo "Deleting log group: $LG"
  aws logs delete-log-group --log-group-name "$LG" --region "$AWS_REGION" || true
done


# 4) Remove your S3 artefacts (stops tiny storage cost)
aws s3 rm "s3://$BUCKET/$S3_PREFIX/artifacts/"
 

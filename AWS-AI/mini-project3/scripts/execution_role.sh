# 1) Create the trust policy (who can assume the role)
cat > trust-policy.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "sagemaker.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
JSON

# 2) Create the role
ROLE_NAME=CloudLabSageMakerExecutionRole
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file://trust-policy.json

#3) Attach the learning-friendly policies
# Managed policies (easy for learning)
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess

aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# 4) Get the Role ARN (
aws iam get-role --role-name "$ROLE_NAME" \
  --query 'Role.Arn' --output text


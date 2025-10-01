# # See policies attached to a role
ROLE=CloudLabSageMakerExecutionRole
aws iam list-attached-role-policies --role-name "$ROLE"

# Inline (role-local) policies, if any:
aws iam list-role-policies --role-name "$ROLE"

# List your account’s customer-managed policies (to find ARNs)
aws iam list-policies --scope Local --query 'Policies[].{Name:PolicyName,Arn:Arn}'

# A safe way to delete a customer-managed IAM policy:
# Set your policy ARN
POLICY_ARN=arn:aws:iam::123456789012:role/CloudLabSageMakerExecutionRole
aws iam delete-policy --policy-arn "$POLICY_ARN"

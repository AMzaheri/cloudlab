# Deployment with AWS SageMaker SDK

This mini-project demonstrates deploying a trained XGBoost model to AWS SageMaker with custom JSON input/output, testing it via both the SageMaker SDK and raw HTTP calls, and safely tearing it down to avoid costs. It’s part of the CloudLab learning series.

After completing this mini-project, you will have gone through the full deployment lifecycle:

- Artefact → S3
- Model object → binds artefact (model_data) + container (XGBoost image) [+ optional entry point]
- Endpoint → run on a chosen instance type
- Prediction → via JSON (SDK or raw HTTP)
- Teardown → clean up endpoint, config, and model


## Prepare model artefact

Run
```bash
python train_and_package.py
```
It trains an XGBoost model locally and packages exactly the way SageMaker’s XGBoost inference container expects (a tarball containing a file named xgboost-model). SageMaker expects a single tar.gz “artefact bundle”.
Output:
 -`model/xgboost-model`: the trained XGBoost booster (binary file).
- `model.tar.gz`: a tarball containing the model/ directory (with xgboost-model inside). This is the artefact we upload to S3 for SageMaker.
 
## One-time setup (local machine)

1. Ensure AWS CLI is configured (credentials + region, e.g. eu-west-2). See `cloudlab/AWS` to learn.

**Use your existing bucket name:** See cloudlab/AWS-AI/mini-project1/ to learn how to create s3 buckets.
- List all buckets you own
```bash
aws s3api list-buckets --query 'Buckets[].Name'
```
- Set environment variables
```bash
export BUCKET=<your-existing-bucket-name>
export AWS_REGION=eu-west-2
export PROJECT=mini-project3
export S3_PREFIX=mini-project3 
```
**Create project prefixes:**

```bash
aws s3api put-object --bucket "$BUCKET" --key "$S3_PREFIX/"
```
2. Install deploy-time dependencies using:
```bash
pip install -r requirements.txt
```
3. Upload the artefact we already built:
```bash
aws s3 cp model.tar.gz s3://$BUCKET/$S3_PREFIX/artifacts/model.tar.gz
```
Inspect the object:
```bash
aws s3 ls "s3://$BUCKET/$S3_PREFIX/artifacts/"
```
SageMaker pulls the artefact from S3 when deploying. The bucket must exist and be readable.

## Execution role (used by the endpoint)

We need to create an execution role. SageMaker runs containers on our behalf. The execution role lets the container read the artefact from S3 and write logs to CloudWatch.

To make IAM, we run some CLI commands. I created a shell script in `src/`, which provides CLI ready commands. We need to run that:
```bash
./execution_role.sh
``` 
-It prints the role’s ARN (e.g., `arn:aws:iam::123456789012:role/CloudLabSageMakerExecutionRole`). If deployment fails immediately with a role error, retry once after a short pause.New IAM roles can take ~10–60s to propagate.

- Set an env var:
```bash
export SAGEMAKER_EXEC_ROLE=arn:aws:iam::123456789012:role/CloudLabSageMakerExecutionRole
```
Replace 123456789012 with your ARN role number. The deployment script will then read the env var. If you forget the numebr, it is your account number and you could retrieve it by:
```bash
aws sts get-caller-identity --query 'Account' --output text
```

## SageMaker deployment

## Deploy with custom JSON I/O

The process includes running the XGBoost container, and a handler script(`src/handler_json.py`) to control input/output. 
- Set env var for s3 model:
```bash
export S3_MODEL="s3://$BUCKET/$S3_PREFIX/artifacts/model.tar.gz"
```
- Deploy the model:
```bash
python src/deploy_xgb_json.py  <endpoint_name>
```
**Example output:**
```bash
'predictions': [0.6932185292243958]}
```
## (Optional) Call the endpoint with raw HTTP (SigV4)

In addition to using the SageMaker SDK (predictor.predict) to call the deployed model, it is also possible to send raw HTTP requests directly to the endpoint. Because SageMaker endpoints are private AWS services, these requests must be signed using AWS Signature Version 4 (SigV4) to prove the caller’s identity. This is the same security mechanism the SDK handles automatically. Calling the endpoint via raw HTTP is useful for learning how the underlying InvokeEndpoint API works and is a first step if you later decide to front the model with API Gateway, which can expose a simpler public URL without requiring clients to generate SigV4 signatures.

To call the endpoint with raw HTTP, after implementing the previous step, run
```bash
python src/call_raw_requests.py <endpoint_name>
```
- Endpoint name should match the one used in the previous step.
- Output should involve status  200, prediction value, and the invoke URL:

**Expected output:**
```bash
200 {"predictions": [0.969414234161377]}
Invoke URL: https://runtime.sagemaker.eu-west-2.amazonaws.com/endpoints/cloudlab-xgb-json-endpoint2/invocations
```
Note:

-The url isn’t a normal webpage we can open in a browser. It only accepts POST calls to `/invocations`, and every request must be SigV4-signed (the SDK/ `requests_aws4auth` code did that).
- If you want a shareable/public URL (no SigV4), put API Gateway in front of the endpoint (optionally with Lambda). That exposes a friendly HTTPS URL for clients; API Gateway handles auth/forwarding.
- For the current free-tier learning project, we  skip this step.
 
## Teardown checklist (cost efficiency for Free Tier use case)
 
After testing, make sure to clean up:
- Delete the endpoint and its endpoint config.
- Delete the Model.

Keep the S3 artefact for reuse, or remove it if you want a clean slate.
- Real-time endpoints bill per hour while up. Keeping clean-up in your script avoids surprises.

Use the provided cleanup script:
```bash
scripts/cleanup_endpoint.sh
```
- If a delete fails because something’s still “Deleting”, just rerun the command after a minute.

- You could then verify if all have gone:
```bash
aws sagemaker list-endpoints --region "$AWS_REGION" --query 'Endpoints[].EndpointName'
aws sagemaker list-models   --region "$AWS_REGION" --query 'Models[].ModelName'

```
### Cleanup

- IAM roles cost £0.
- If you ever want to remove role policy see `scripts/remove_policy.sh`.

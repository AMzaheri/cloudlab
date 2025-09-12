# AWS-AI Mini-Project 1 — S3 ETL 
 
This project demonstrates data movement pattern for ML/AI on AWS: store a dataset in Amazon S3, download it locally (or to compute), run a small Python preprocessing step, and upload cleaned outputs back to S3.

## Project structure
```
cloudlab/
    └── AWS-AI/
        └── mini-project1/
            ├── README.md
            ├── `s3_etl.py`
            ├── requirements.txt
            └── data/
                └── sample.csv # (local test file)
```

## Step-by-step guide

**1. Create (or reuse) your S3 bucke**t

Pick a globally unique bucket name:
```bash
aws s3 mb s3://<your-bucket> --region eu-west-2
```
**2. (Recommended) Create a least-privilege IAM user for this project**
 
This avoids using your admin key for day-to-day work. This script creates/updates:
- a minimal S3 policy limited to your bucket + prefix
- a dedicated IAM user
- attaches the policy to the user
```bash
./scripts/setup_mp1_user.sh --bucket <your-bucket> --prefix aws-ai/mini-project1 --region eu-west-2
```

Now manually create an access key for that new user (to keep secrets out of logs):

```bash
aws iam create-access-key --user-name cloudlab-mp1-user
```
Copy the AccessKeyId and SecretAccessKey, then configure a new profile:

```bash
aws configure --profile mp1
```
I used  region: eu-west-2  |  output: json

Note: If you prefer to use your existing admin profile for a quick try, you can skip this step and use that profile—just be mindful of security.

**3. Add a toy sample CSV (or use your own dataset)**

```bash
mkdir -p data
printf "id,name,plan\n1,Alice,Basic\n2,Bob,Pro\n2,Bob,Pro\n3, Carol ,Basic\n" > data/sample.csv
```

**4. Run the ETL (upload → download → preprocess → re-upload)**

```bash
export M1_BUCKET=<your-bucket>
export M1_PREFIX=aws-ai/mini-project1
```
If using the least-privilege profile:

```bash
AWS_PROFILE=mp1 python s3_etl.py \
  --bucket "$M1_BUCKET" \
  --region eu-west-2 \
  --key-prefix "$M1_PREFIX" \
  --local-csv data/sample.csv
```
(Or, with your default/admin profile, omit AWS_PROFILE=mp1)

**5. Verify outputs in S3**

```bash
aws s3 ls s3://$M1_BUCKET/$M1_PREFIX/raw/
aws s3 ls s3://$M1_BUCKET/$M1_PREFIX/processed/
```

## Why this matters

-Mirrors how ML/AI pipelines fetch and persist data with S3.
-Produces both CSV and Parquet (columnar, analytics-friendly).
-Demonstrates least privilege IAM for safe, real-world setups.
-Fits within AWS Free Tier at this scale.

## Cleanup summary

-To clean up S3 objects:

```bash
aws s3 rm s3://$M1_BUCKET/$M1_PREFIX --recursive
```
This fits within Free Tier at this scale. Keep total storage small and avoid unnecessary re‑downloads.

-To delete the IAM user/policy after you’re done:

```bash
./scripts/cleanup_mp1_user.sh --user cloudlab-mp1-user --policy-name CloudLabS3MiniProjAccess
```

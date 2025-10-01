# CloudLab

This repository documents my journey to learning cloud engineering.

## AWS Essentials
This phase focuses on building a strong foundation in cloud computing with AWS.

AWS work is organised under [`cloudlab/AWS`](AWS/README.md) and currently includes:
- AWS account setup with secure IAM admin user
- AWS CLI installation & configuration
- EC2 practice (launch, connect, cleanup) — CLI-only
- Upcoming: S3 static site mini-project (after completing Module 6 of AWS Cloud Practitioner Essentials)

## AWS-AI Mini-Projects

### 1. S3 ETL: Upload → Download → Preprocess → Re-upload
Folder: [`AWS-AI/mini-project1`](AWS-AI/mini-project1)

This project demonstrates a realistic ML/AI data flow on AWS:

- Uploads a CSV dataset to **Amazon S3**
- Downloads it for local preprocessing
- Cleans and deduplicates the data with **Pandas**
- Saves results in both **CSV** and **Parquet** formats
- Re-uploads outputs back to S3

It also introduces **least-privilege IAM** practice, with shell scripts to create and clean up a dedicated project user and policy.

### 2. Mini-project 2: CLI-only ML on AWS (XGBoost + manual HPO, S3)

Path: `AWS-AI/mini-project2/`  
What: Train a small XGBoost model **from the CLI**, run a short manual HPO, and store artefacts/metrics in **Amazon S3** (Free-Tier friendly; no SageMaker jobs).

This mini-project demonstrates:
- CLI-driven ML workflow on AWS (local training; artefacts/metrics in Amazon S3)
- Lightweight hyper-parameter search
- Optional companion notebook to run the project
- Cost-aware use of S3 prefixes for tidy artefacts

### 3. Mini-project 3: Deployment with SageMaker SDK (XGBoost + JSON I/O)

Path: `AWS-AI/mini-project3/`  
What: Package a locally trained XGBoost model, upload it to **Amazon S3**, and deploy it on **AWS SageMaker** as a real-time inference endpoint with custom JSON I/O (Free-Tier friendly).

This mini-project demonstrates:
- End-to-end model deployment workflow with the SageMaker Python SDK
- Use of custom inference handlers (`handler_json.py`) for JSON input/output
- Testing predictions via both the SageMaker SDK and raw HTTP (SigV4-signed) requests
- Cost-aware teardown of endpoints/models to avoid ongoing charges


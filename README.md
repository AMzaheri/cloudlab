# CloudLab

This repository documents my journey to becoming a cloud engineer. It follows the cloud engineer roadmap suggested in [this YouTube video](https://www.youtube.com/watch?v=6eroP2XGtTI).

## Phase 1: AWS Essentials
This phase focuses on building a strong foundation in cloud computing with AWS.

It includes:
- Learning core cloud concepts (IaaS, PaaS, SaaS, public/private/hybrid clouds)
- Enrolling in AWS Cloud Practitioner Essentials
- Setting up a secure AWS account
- Creating and configuring an IAM admin user
- Installing and configuring the AWS CLI
- Verifying the CLI setup with test commands
- Preparing for the first mini-project (S3 static site) after completing AWS Cloud Practitioner Essentials Module 6


## AWS Account Setup & CLI Configuration

### 1. AWS Account Creation
- Signed up for AWS Free Tier
- Enabled Multi-Factor Authentication (MFA) for the root account

### 2. IAM Admin User
- Created IAM user: `myadminname`
- Attached `AdministratorAccess` policy
- Enabled console and programmatic access
- Generated and securely stored Access Key ID & Secret Access Key

### 3. AWS CLI Installation & Configuration
- Installed AWS CLI in a conda environment
- Configured CLI with `aws configure`:
  - Default region: `eu-west-2`
  - Output format: `json`
- Verified setup with:
  ```bash
  aws sts get-caller-identity
  aws s3 ls


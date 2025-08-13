# AWS Essentials — CloudLab

This folder contains all AWS-specific learning and mini-projects I practiced.

## AWS Account Setup & CLI Configuration

### 1. AWS Account Creation (AWS Console)
- Signed up for AWS Free Tier
- Enabled Multi-Factor Authentication (MFA) for the root account

### 2. IAM Admin User (AWS Console)
- Created IAM user: `myadminname`
- Attached `AdministratorAccess` policy
- Enabled console and programmatic access
- Generated and securely stored Access Key ID & Secret Access Key

### 3. AWS CLI Installation & Configuration (my local terminal)
- Installed AWS CLI in a conda environment
- Configured CLI with `aws configure`:
  - Default region: `eu-west-2`
  - Output format: `json`
- Verified setup with:
  ```bash
  aws sts get-caller-identity
  aws s3 ls
  ```

## EC2 Practice (CLI-only)

### What I did
- Generated SSH key `cloudlab-key` (stored locally; chmod 400).
- Created security group `cloudlab-sg` allowing SSH from my current IP.
- Launched a Free Tier Amazon Linux 2023 micro instance (t3.micro with t2.micro fallback).
- Saved IDs/IPs in `cloudlab/AWS/` and connected via SSH.
- Verified system with `uname -a`, `/etc/os-release`, `uptime`.
- Cleaned up with `cleanup_ec2.sh` (terminates instance and tries to delete SG).

### Commands & scripts
- `create_security_group.sh` — creates/reuses SG and adds SSH rule for current IP.
- `launch_ec2.sh` — launches/reuses instance; prints SSH command; saves IDs.
- `ssh_ec2.sh` — connects using saved IP and key.
- `cleanup_ec2.sh` — terminates instance and cleans local files.

## Quick Start Guide for AWS Practice

If you want to replicate my AWS practice, here’s the order I followed:

1. **Create AWS account** (AWS Console)  
   - Enable MFA for the root account.

2. **Create IAM admin user** (AWS Console)  
   - Give `AdministratorAccess` policy and generate access keys.

3. **Install & configure AWS CLI** (Local terminal)  
   ```bash
   aws configure
   ```
4. **EC2 CLI practice (Local terminal) — run scripts in this order:**

   - `create_security_group.sh` → creates/reuses an SSH-allowed security group for your IP.  
   - `launch_ec2.sh` → launches a Free Tier Amazon Linux EC2 instance.  
   - `ssh_ec2.sh` → connects to the instance via SSH.  
   - **When finished:** `cleanup_ec2.sh` → terminates the instance and cleans up.

> ⚠️ Always run `cleanup_ec2.sh` after you finish to avoid charges.


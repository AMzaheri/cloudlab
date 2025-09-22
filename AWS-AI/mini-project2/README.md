# ML (XGBoost) via CLI on AWS (Manual HPO, S3 artefacts)

Lightweight ML experiments run entirely from the CLI, with manual HPO and artefacts stored in Amazon S3 — designed to stay within the AWS Free Tier.
Training runs locally (in the notebook kernel or via CLI), and artefacts/metrics are stored in **S3** under a project prefix.

## What this shows

- CLI-only ML workflow (Python scripts run locally)
- Training a small XGBoost model and reporting AUC/F1
- Manual hyper-parameter search (short random search) with saved summary
- Artefacts and metrics stored in Amazon S3 under `s3://$BUCKET/$S3_PREFIX/...`
- Cost-aware setup designed to stay within the AWS Free Tier.


## Repo layout

```
cloudlab/AWS-AI/mini-project2/
                ├─ notebooks/ml_free_tier_xgb.ipynb
                ├─ src/train_local.py
                ├─ src/hpo_loop.py
                ├─ src/s3_useful_commands	Useful S3 commands to check from your local terminal
                └─ README.md
```

# Install dependencies

```bash
pip install -r requirements.txt
```
## Prerequisites

- AWS account with the **AWS CLI** configured (`aws configure`)
- Python 3.10+ with `pip` (conda is fine)
- An S3 bucket in **your chosen region** (e.g. `eu-west-2`)

## How to run

### CLI-driven ML workflow on AWS

1. **Set environment variables**
 
Use your existing bucket name: see cloudlab/AWS-AI/mini-project1/ to learn how to create s3 bucjets.
```bash
export BUCKET=<your-existing-bucket-name>
export AWS_REGION=eu-west-2
export PROJECT=mini-project2
export S3_PREFIX=mini-project2
```
Create project prefixes:

```bash
aws s3api put-object --bucket "$BUCKET" --key "$S3_PREFIX/data/"
aws s3api put-object --bucket "$BUCKET" --key "$S3_PREFIX/artifacts/"
aws s3api put-object --bucket "$BUCKET" --key "$S3_PREFIX/metrics/"
```

2. **Train ML model (XGBoost, CPU):**

```bash
python src/train_local.py
```

3. **Run mini HPO:**

```bash
python src/hpo_loop.py                           # runs 10 trials
# Or you could provide arguments:
python src/hpo_loop.py --trials 5 --seed 123 --n-jobs 2
```

**Inspect outputs**

```bash
aws s3 ls "s3://$BUCKET/$S3_PREFIX/metrics/"
aws s3 ls "s3://$BUCKET/$S3_PREFIX/artifacts/"
```

### Notebook (optional)

`notebooks/ml_free_tier_xgb.ipynb` is a readable companion to the CLI workflow. It walks through the same steps (load data → train a small XGBoost model → mini HPO → upload artefacts/metrics to Amazon S3) and is useful for GitHub viewers. The project runs entirely from the CLI; the notebook is included for clarity and reproducibility.


## Environment variables

| Name        | Required | Example          | Notes                              |
|-------------|----------|------------------|------------------------------------|
| `AWS_REGION`| ✅       | `eu-west-2`      | Must match your S3 bucket region.  |
| `BUCKET`    | ✅       | `my-cloudlab-bkt`| Existing bucket you control.       |
| `S3_PREFIX` | ✅       | `mini-project2`  | Keeps this project’s files tidy.   |
| `PROJECT`   | ❌       | `mini-project2`  | Used only in metadata.             |

---

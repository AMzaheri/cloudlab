# cloudlab/AWS-AI/mini-project2/src/train_local.py
"""
Train a small XGBoost model locally and upload artefacts/metrics to S3.

Env vars (required):
  - AWS_REGION
  - BUCKET
Optional:
  - S3_PREFIX   # e.g. "mini-project2" to keep projects separated
  - PROJECT     # defaults to "mini-project2"

CLI flags (optional):
  --seed 42
  --test-size 0.2
  --threshold 0.5
  --n-estimators 200
  --max-depth 4
  --learning-rate 0.05
  --no-upload                # save locally only
  --model-out artifacts/model.joblib
  --metrics-out metrics/metrics.json
"""

#------------------------------------------------------
import argparse
import json
import os
import subprocess
import tempfile

import joblib
import numpy as np
import pandas as pd
from sklearn.datasets import load_breast_cancer
from sklearn.metrics import f1_score, roc_auc_score
from sklearn.model_selection import train_test_split
from xgboost import XGBClassifier

#------------------------------------------------------
def s3_uri(bucket: str, key: str, prefix: str | None) -> str:
    """
    Construct and return a qualified Amazon S3 Uniform Resource Identifier (URI)
    from the arguments: a bucket name, a key, and an optional prefix.
    """
    base = (prefix.strip("/") + "/") if prefix else ""
    key = key.lstrip("/")
    return f"s3://{bucket}/{base}{key}"

#------------------------------------------------------
def aws_s3_cp(local_path: str, s3_path: str):
    """
    Copy a file from a local path to an Amazon S3 bucket 
    using the AWS Command Line Interface (CLI).
    """
    subprocess.run(["aws", "s3", "cp", local_path, s3_path], check=True)

#------------------------------------------------------
def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--test-size", type=float, default=0.2)
    p.add_argument("--threshold", type=float, default=0.5)
    p.add_argument("--n-estimators", type=int, default=200)
    p.add_argument("--max-depth", type=int, default=4)
    p.add_argument("--learning-rate", type=float, default=0.05)
    p.add_argument("--no-upload", action="store_true", help="Skip S3 upload")
    p.add_argument("--model-out", default="artifacts/model.joblib")
    p.add_argument("--metrics-out", default="metrics/metrics.json")
    return p.parse_args()

#------------------------------------------------------
def main():
    args = parse_args()

    region = os.environ.get("AWS_REGION")
    bucket = os.environ.get("BUCKET")
    prefix = os.environ.get("S3_PREFIX")
    project = os.environ.get("PROJECT", "mini-project2")

    if not bucket or not region:
        raise SystemExit("Please set AWS_REGION and BUCKET environment variables.")

    # Load dataset (small, built-in)
    data = load_breast_cancer(as_frame=True)
    X = data.frame.drop(columns=["target"])
    y = data.frame["target"]

    X_tr, X_val, y_tr, y_val = train_test_split(
        X, y, test_size=args.test_size, random_state=args.seed, stratify=y
    )

    # Model
    clf = XGBClassifier(
        n_estimators=args.n_estimators,
        max_depth=args.max_depth,
        learning_rate=args.learning_rate,
        subsample=0.9,
        colsample_bytree=0.9,
        eval_metric="logloss",
        tree_method="hist",
        random_state=args.seed,
        n_jobs=2,
    )
    clf.fit(X_tr, y_tr)

    # Metrics
    proba = clf.predict_proba(X_val)[:, 1]
    pred = (proba >= args.threshold).astype(int)
    metrics = {
        "project": project,
        "seed": args.seed,
        "test_size": args.test_size,
        "threshold": args.threshold,
        "roc_auc": float(roc_auc_score(y_val, proba)),
        "f1": float(f1_score(y_val, pred)),
        "n_estimators": args.n_estimators,
        "max_depth": args.max_depth,
        "learning_rate": args.learning_rate,
    }

    with tempfile.TemporaryDirectory() as tmp:
        model_path = os.path.join(tmp, "model.joblib")
        metrics_path = os.path.join(tmp, "metrics.json")

        joblib.dump(clf, model_path)
        with open(metrics_path, "w") as f:
            json.dump(metrics, f, indent=2)

        if args.no_upload:
            # Save to current working directory in the same relative structure
            local_model_out = os.path.join(os.getcwd(), args.model_out)
            local_metrics_out = os.path.join(os.getcwd(), args.metrics_out)
            os.makedirs(os.path.dirname(local_model_out), exist_ok=True)
            os.makedirs(os.path.dirname(local_metrics_out), exist_ok=True)
            os.replace(model_path, local_model_out)
            os.replace(metrics_path, local_metrics_out)
            print("Saved locally:")
            print("  ", local_model_out)
            print("  ", local_metrics_out)
        else:
            s3_model = s3_uri(bucket, args.model_out, prefix)
            s3_metrics = s3_uri(bucket, args.metrics_out, prefix)
            aws_s3_cp(model_path, s3_model)
            aws_s3_cp(metrics_path, s3_metrics)
            print("Uploaded:")
            print("  ", s3_model)
            print("  ", s3_metrics)

    print("Done. Metrics:", json.dumps(metrics, indent=2))

#------------------------------------------------------
if __name__ == "__main__":
    main()


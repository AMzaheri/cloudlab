# cloudlab/AWS-AI/mini-project2/src/hpo_loop.py
"""
Manual HPO loop (random search) for a tiny, free-tier-friendly experiment.

Env vars (required):
  - AWS_REGION
  - BUCKET
Optional:
  - S3_PREFIX   # e.g. "mini-project2" to keep projects separated
  - PROJECT     # defaults to "mini-project2"

CLI flags (optional):
  --trials 10
  --seed 42
  --n-jobs 2
  --out metrics/hpo_summary.json
  --no-upload                 # save locally only
"""
#------------------------------------------------------
import argparse
import json
import os
import random
import subprocess
import tempfile

import numpy as np
from sklearn.datasets import load_breast_cancer
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split
from xgboost import XGBClassifier

#------------------------------------------------------
def s3_uri(bucket: str, key: str, prefix: str | None) -> str:
    base = (prefix.strip("/") + "/") if prefix else ""
    key = key.lstrip("/")
    return f"s3://{bucket}/{base}{key}"

#------------------------------------------------------
def aws_s3_cp(local_path: str, s3_path: str):
    subprocess.run(["aws", "s3", "cp", local_path, s3_path], check=True)


#------------------------------------------------------
def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--trials", type=int, default=10)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--n-jobs", type=int, default=2, help="XGBoost n_jobs")
    p.add_argument("--out", default="metrics/hpo_summary.json")
    p.add_argument("--no-upload", action="store_true")
    return p.parse_args()

#------------------------------------------------------
def sample_params(rng: random.Random):
    return {
        "n_estimators": rng.choice([100, 200, 300]),
        "max_depth": rng.choice([3, 4, 5]),
        "learning_rate": rng.choice([0.03, 0.05, 0.1]),
        "subsample": rng.choice([0.8, 0.9, 1.0]),
        "colsample_bytree": rng.choice([0.8, 0.9, 1.0]),
    }


#------------------------------------------------------
def main():
    args = parse_args()

    region = os.environ.get("AWS_REGION")
    bucket = os.environ.get("BUCKET")
    prefix = os.environ.get("S3_PREFIX")
    project = os.environ.get("PROJECT", "mini-project2")

    if not bucket or not region:
        raise SystemExit("Please set AWS_REGION and BUCKET environment variables.")

    # Reproducibility
    rng = random.Random(args.seed)
    np.random.seed(args.seed)

    # Data
    data = load_breast_cancer(as_frame=True)
    X = data.frame.drop(columns=["target"])
    y = data.frame["target"]
    X_tr, X_val, y_tr, y_val = train_test_split(
        X, y, test_size=0.2, random_state=args.seed, stratify=y
    )

    best = {"roc_auc": -1.0, "params": None, "trial": None}
    trials = []

    for t in range(1, args.trials + 1):
        params = sample_params(rng)
        clf = XGBClassifier(
            **params,
            eval_metric="logloss",
            tree_method="hist",
            random_state=args.seed + t,  # small change per trial
            n_jobs=args.n_jobs,
        )
        clf.fit(X_tr, y_tr)
        proba = clf.predict_proba(X_val)[:, 1]
        auc = float(roc_auc_score(y_val, proba))
        trials.append({"trial": t, "roc_auc": auc, "params": params})
        if auc > best["roc_auc"]:
            best = {"roc_auc": auc, "params": params, "trial": t}

        print(f"[{t}/{args.trials}] AUC={auc:.5f} params={params}")

    summary = {
        "project": project,
        "seed": args.seed,
        "n_jobs": args.n_jobs,
        "trials": trials,
        "best": best,
    }

    with tempfile.TemporaryDirectory() as tmp:
        out_path = os.path.join(tmp, "hpo_summary.json")
        with open(out_path, "w") as f:
            json.dump(summary, f, indent=2)

        if args.no_upload:
            local_out = os.path.join(os.getcwd(), args.out)
            os.makedirs(os.path.dirname(local_out), exist_ok=True)
            os.replace(out_path, local_out)
            print("Saved locally:", local_out)
        else:
            s3_out = s3_uri(bucket, args.out, prefix)
            aws_s3_cp(out_path, s3_out)
            print("Uploaded:", s3_out)

    print("Best trial:", json.dumps(best, indent=2))

#------------------------------------------------------
if __name__ == "__main__":
    main()


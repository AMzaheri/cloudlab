#-----------------------------------------------
# Minimal XGBoost model -> model.tar.gz for SageMaker (XGBoost container)
# Usage: python train_and_package.py
#-----------------------------------------------
import os, tarfile, numpy as np
from pathlib import Path
from sklearn.datasets import make_classification
from sklearn.model_selection import train_test_split
import xgboost as xgb

#-----------------------------------------------main
# 1) Make a small binary dataset
X, y = make_classification(n_samples=500, 
                           n_features=8, n_informative=5,
                           n_redundant=0, random_state=42)
X_train, X_val, y_train, y_val = train_test_split(X,
                                 y, test_size=0.2, random_state=42)
dtrain, dval = xgb.DMatrix(X_train, label=y_train), xgb.DMatrix(X_val, label=y_val)

# 2) Train a lightweight Booster
params = {
    "objective": "binary:logistic",
    "max_depth": 3,
    "eta": 0.2,
    "subsample": 0.8,
    "eval_metric": "logloss",
    "verbosity": 0,
}
bst = xgb.train(params, dtrain, num_boost_round=60, evals=[(dval, "val")])

# 3) Save in SageMaker-friendly layout: model/xgboost-model inside model.tar.gz
ROOT = Path(__file__).resolve().parents[1]  # mini-project3/
MODEL_DIR = ROOT / "model"
MODEL_DIR.mkdir(parents=True, exist_ok=True)
model_path = MODEL_DIR / "xgboost-model"   # SageMaker XGBoost container
bst.save_model(model_path)

with tarfile.open("model.tar.gz", "w:gz") as tar:
    tar.add("model", arcname="model")

print("Wrote: model/xgboost-model and model.tar.gz")


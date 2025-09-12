#!/usr/bin/env python3
import argparse
import os 
#  tempfile manages temporary files and directories. It is part of the Python Standard Library, so no installation is needed.
import tempfile
import logging
from pathlib import Path

# Boto3 is the official Software Development Kit (SDK) for Python to create, configure, and manage AWS
import boto3

import pandas as pd

try:
    import pyarrow  # noqa: F401 (ensures parquet support)
except Exception as e:
    raise SystemExit("pyarrow is required for Parquet output. Run: pip install pyarrow") from e

logging.basicConfig(level=logging.INFO, 
                    format="[%(levelname)s] %(message)s")

#------------------------------------------------
def boto3_clients(region: str):
    session = boto3.session.Session(region_name=region)
    s3 = session.client("s3")
    return s3

#------------------------------------------------
def upload_file(s3, bucket: str, local_path: Path, key: str):
    logging.info(f"Uploading to s3://{bucket}/{key} ← {local_path}")
    s3.upload_file(str(local_path), bucket, key)

#------------------------------------------------
def download_file(s3, bucket: str, key: str, local_path: Path):
    logging.info(f"Downloading s3://{bucket}/{key} → {local_path}")
    local_path.parent.mkdir(parents=True, exist_ok=True)
    s3.download_file(bucket, key, str(local_path))

#------------------------------------------------
def preprocess_csv(in_csv: Path, out_csv: Path, out_parquet: Path):
    logging.info(f"Preprocessing {in_csv} → {out_csv}, {out_parquet}")
    df = pd.read_csv(in_csv)
    # Trim whitespace on object columns
    for c in df.select_dtypes(include=["object"]).columns:
        df[c] = df[c].astype(str).str.strip()
    # Drop fully empty rows and duplicates
    before = len(df)
    df = df.dropna(how="all").drop_duplicates()
    after = len(df)
    logging.info(f"Rows: {before} → {after} (after clean)")

    out_csv.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out_csv, index=False)
    #df.to_parquet(out_parquet, index=False)
    df.to_parquet(out_parquet, index=False, engine="fastparquet")


#------------------------------------------------main
def main():
    p = argparse.ArgumentParser(description=
                    "S3 ETL: upload → download → preprocess → upload")
    p.add_argument("--bucket", required=True, 
                    help="S3 bucket name")
    p.add_argument("--region", 
                   default=os.getenv("AWS_REGION", 
                   "eu-west-2"))
    p.add_argument("--key-prefix", default="aws-ai/mini-project1", 
                   help="S3 key prefix root")
    p.add_argument("--local-csv", required=True, type=Path, 
                   help="Path to local CSV to upload")
    args = p.parse_args()

    s3 = boto3_clients(args.region)

    # 1) Upload RAW CSV
    raw_key = f"{args.key_prefix}/raw/{args.local_csv.name}"
    upload_file(s3, args.bucket, args.local_csv, raw_key)

    with tempfile.TemporaryDirectory() as tmpd:
        tmp_raw = Path(tmpd) / args.local_csv.name
        # 2) Download RAW CSV
        download_file(s3, args.bucket, raw_key, tmp_raw)

        # 3) Preprocess locally → outputs
        stem = args.local_csv.stem
        out_csv = Path(tmpd) / f"{stem}_clean.csv"
        out_parquet = Path(tmpd) / f"{stem}_clean.parquet"
        preprocess_csv(tmp_raw, out_csv, out_parquet)

        # 4) Upload processed artifacts
        proc_csv_key = f"{args.key_prefix}/processed/{out_csv.name}"
        proc_parquet_key = f"{args.key_prefix}/processed/{out_parquet.name}"
        upload_file(s3, args.bucket, out_csv, proc_csv_key)
        upload_file(s3, args.bucket, out_parquet, proc_parquet_key)

    logging.info("Done. Check your S3 prefixes: raw/ and processed/.")

#------------------------------------------------

if __name__ == "__main__":
    main()


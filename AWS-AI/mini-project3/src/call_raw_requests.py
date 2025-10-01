import sys
import json, requests, boto3
from requests_aws4auth import AWS4Auth

REGION = os.environ["AWS_REGION"]
ENDPOINT = sys.argv[1]   # match your deployed name

session = boto3.Session(region_name=REGION)
creds   = session.get_credentials().get_frozen_credentials()
awsauth = AWS4Auth(creds.access_key, creds.secret_key, REGION, "sagemaker",
                   session_token=creds.token)

url = f"https://runtime.sagemaker.{REGION}.amazonaws.com/endpoints/{ENDPOINT}/invocations"
payload = {"instances": [[0.12, 1.7, 3.14, 9.81, 0.5, 0.2, 0.01, 1.0]]}

r = requests.post(url,
                  auth=awsauth,
                  headers={"Content-Type": "application/json"},
                  data=json.dumps(payload))
print(r.status_code, r.text)
print("Invoke URL:", url)

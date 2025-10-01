import os, sys, sagemaker
from sagemaker.xgboost.model import XGBoostModel
from sagemaker.serializers import JSONSerializer
from sagemaker.deserializers import JSONDeserializer
import boto3
#---------------------------------------
ROLE_ARN   = os.environ["SAGEMAKER_EXEC_ROLE"] 
REGION     = os.environ["AWS_REGION"]
S3_MODEL   = os.environ["S3_MODEL"]
ENDPOINT   = sys.argv[1] #"cloudlab-xgb-json-endpoint"
MODEL_NAME =  "cloudlab-xgb-json-model"

xgb_model = XGBoostModel(
    model_data=S3_MODEL,
    role=ROLE_ARN,
    entry_point="handler_json.py",
    source_dir="src",
    framework_version="1.7-1",
    name=MODEL_NAME,
)

predictor = xgb_model.deploy(endpoint_name=ENDPOINT,
                             instance_type="ml.t2.medium",
                             initial_instance_count=1)

# quick test
predictor.serializer   = JSONSerializer()
predictor.deserializer = JSONDeserializer()
print(predictor.predict({"instances": [[0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8]]}))

# cleanup
#predictor.delete_endpoint(delete_endpoint_config=True)
#boto3.client("sagemaker", region_name=REGION).delete_model(ModelName=MODEL_NAME)


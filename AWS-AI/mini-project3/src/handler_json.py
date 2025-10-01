# src/handler_json.py
import json, numpy as np, xgboost as xgb
#-------------------------------------------------------
def model_fn(model_dir):
    bst = xgb.Booster()
    bst.load_model(f"{model_dir}/model/xgboost-model")
    return bst

def input_fn(request_body, content_type="application/json"):
    data = np.array(json.loads(request_body)["instances"])
    return xgb.DMatrix(data)

def predict_fn(dmatrix, booster):
    return booster.predict(dmatrix).tolist()

def output_fn(preds, accept="application/json"):
    return json.dumps({"predictions": preds})


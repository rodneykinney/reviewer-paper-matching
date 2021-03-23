import json
import os

from flask import Flask, Response, request

from suggest_reviewers import load_model, create_embeddings

app = Flask("ACL Paper Embeddings")

model, epoch = load_model(None, os.environ['MODEL_FILE'], force_cpu=True)
model.eval()

@app.route('/', methods=['POST'])
def get_embedding():
    body = request.json
    abstract = body['abstract']
    e = create_embeddings(model, [abstract])
    result = [x for x in e[0]]
    return Response(json.dumps(result), mimetype='application/json')



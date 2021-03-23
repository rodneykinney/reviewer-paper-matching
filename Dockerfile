FROM python:3.7

WORKDIR /work

RUN pip install -r gunicorn
RUN pip install -r requirements.txt

COPY . /work

COPY scratch .

ENV MODEL_FILE scratch/similarity-model.pt

CMD gunicorn -b 0.0.0.0:8080 serve_embeddings:app

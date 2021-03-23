FROM python:3.7

WORKDIR /work

RUN pip install gunicorn
COPY requirements.txt .
RUN pip install -r requirements.txt
RUN pip install pandas

COPY . /work

ENV MODEL_FILE scratch/similarity-model.pt

CMD gunicorn -b 0.0.0.0:8080 serve_embeddings:app

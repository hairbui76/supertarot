FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt ./
RUN python -m pip install --upgrade pip \
    && python -m pip install -r requirements.txt

COPY app ./app
COPY learning ./learning
COPY data/output ./data/output
COPY data/embeddings ./data/embeddings
COPY data/images ./data/images

RUN mkdir -p /app/data/bot_state

CMD ["python", "-m", "app"]
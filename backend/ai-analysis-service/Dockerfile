FROM python:3.11-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN echo "setuptools<81" > /tmp/pip-constraints.txt \
    && pip install --no-cache-dir --upgrade "setuptools<81" wheel \
    && PIP_CONSTRAINT=/tmp/pip-constraints.txt pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

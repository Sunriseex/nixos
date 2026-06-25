FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update \
 && apt-get install -y python3 python3-pip \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt python-multipart

COPY faster_whisper_server.py .

CMD ["python3", "faster_whisper_server.py"]

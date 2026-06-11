FROM python:3.11-slim AS builder

ARG WHISPER_CPP_REF=master
ARG WHISPER_CPP_MODEL_FILE=ggml-large-v3-turbo-q5_0.bin

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN git clone --depth 1 --branch "${WHISPER_CPP_REF}" https://github.com/ggml-org/whisper.cpp.git whisper.cpp \
    && cmake -S /opt/whisper.cpp -B /opt/whisper.cpp/build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /opt/whisper.cpp/build --config Release -j "$(nproc)"

FROM python:3.11-slim

ARG WHISPER_CPP_MODEL_FILE=ggml-large-v3-turbo-q5_0.bin

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/whisper.cpp /opt/whisper.cpp
COPY infrastructure/scripts/whisper-metal-server.py /app/whisper-server.py

ENV WHISPER_CPP_DIR=/opt/whisper.cpp
ENV WHISPER_CPP_BIN=/opt/whisper.cpp/build/bin/whisper-cli
ENV WHISPER_CPP_MODEL=/models/whisper-cpp/${WHISPER_CPP_MODEL_FILE}
ENV AI_ANALYSIS_WORK_HOST_DIR=/work
ENV AI_ANALYSIS_WORK_CONTAINER_DIR=/work
ENV WHISPER_CPP_SERVER_HOST=0.0.0.0
ENV WHISPER_CPP_SERVER_PORT=8787

EXPOSE 8787

CMD ["python3", "/app/whisper-server.py"]

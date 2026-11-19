# podman build -t ytj:latest .
FROM docker.io/library/python:3-slim
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg tzdata \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir "yt-dlp[default]"

# Java script runtime to help ytd deal with bot detection
COPY --from=docker.io/denoland/deno:bin /deno /usr/local/bin/deno

# UDP trigger listener & daily scheduler
COPY trigger.py /app/trigger.py

WORKDIR /downloads
ENTRYPOINT ["python3", "-u", "/app/trigger.py"]

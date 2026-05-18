# yt-dlp metadata microservice — deploy to Fly.io / Railway / Cloud Run.
# Deno Edge Functions CANNOT spawn yt-dlp, so this runs as its own container.
FROM python:3.12-slim

# ffmpeg not needed for metadata-only, but harmless + future-proof
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

# Cookie files are mounted/secret-injected at runtime to /data
RUN mkdir -p /data
ENV IG_COOKIES=/data/ig_cookies.txt
ENV TT_COOKIES=/data/tt_cookies.txt

EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]

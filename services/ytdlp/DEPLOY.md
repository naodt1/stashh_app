# yt-dlp service — deployment

The service is a stateless Docker container (`Dockerfile` in this dir).
It only runs when the `extract-metadata` Edge Function calls it as a
last-resort tier (Instagram / some TikTok). Cold-start latency only
affects those cases — everything else is handled by oEmbed/OG.

## Option A — Render (current, free)

- Web Service, Docker, root dir `services/ytdlp`
- Env: `SERVICE_SECRET`
- Free tier spins down after ~15 min idle → 30–50 s cold start.
- Mitigated app-side: the app pings `/health` when the add/share sheet
  opens (`YTDLP_HEALTH_URL` in `.env`).

## Option B — Google Cloud Run (recommended for production)

Scales to zero (pay ~nothing when idle) but cold-starts in ~2–5 s, and
the free tier covers ~2M requests/month. One-time setup:

```bash
# 1. Auth + project
gcloud auth login
gcloud config set project YOUR_GCP_PROJECT_ID
gcloud services enable run.googleapis.com cloudbuild.googleapis.com

# 2. Build + deploy straight from this directory
cd services/ytdlp
gcloud run deploy stashh-ytdlp \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --concurrency 4 \
  --timeout 60 \
  --min-instances 0 \
  --set-env-vars "SERVICE_SECRET=YOUR_SECRET"

# (optional) eliminate cold starts entirely — ~always-on, still cheap:
#   --min-instances 1
```

`gcloud run deploy --source .` uses the existing `Dockerfile`
automatically (Cloud Build). It prints a service URL like
`https://stashh-ytdlp-xxxx.run.app`.

Then repoint Supabase + the app:

```bash
supabase secrets set YTDLP_SERVICE_URL="https://stashh-ytdlp-xxxx.run.app"
# .env (app):  YTDLP_HEALTH_URL=https://stashh-ytdlp-xxxx.run.app/health
```

### Instagram cookies on Cloud Run
Mount the Netscape cookie file via a secret:

```bash
gcloud secrets create ig_cookies --data-file=ig_cookies.txt
gcloud run services update stashh-ytdlp --region us-central1 \
  --update-secrets=/data/ig_cookies.txt=ig_cookies:latest
```
(`IG_COOKIES=/data/ig_cookies.txt` is already set in the Dockerfile.)

## Notes
- `min-instances 0` = pay only when used, ~2–5 s cold start.
- `min-instances 1` = no cold start, ~a few $/mo.
- `--allow-unauthenticated` is required (the Edge Function calls it over
  plain HTTPS); the `SERVICE_SECRET` header is the access control.

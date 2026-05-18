# Stashh

Your AI second brain for saved videos & links. Share a reel, TikTok,
YouTube Short, article or note from any app — Stashh extracts the title,
thumbnail and transcript, categorises it with AI, and makes it
semantically searchable. No manual folders or tagging required.

## Features

- **Share-sheet capture** from any app (links, video, images, text)
- **AI categorisation** — 15 primary buckets + mood / intent / topics /
  tags / length / skill level, all auto-assigned
- **Semantic search** (pgvector embeddings) — search by meaning, not keywords
- **Smart Collections** — dynamic, auto-updating; appear only once the AI
  has matching items
- **User collections** — manual, multi-membership, bulk add
- **Auto-save on share** (optional) — zero-tap capture
- **Transcription** of video captions (via the yt-dlp service)

## Stack

- Flutter (Android-first) · Dart
- Supabase (Postgres + Auth + Storage + Edge Functions + pgvector)
- OpenAI (`gpt-4o-mini` for categorisation, `text-embedding-3-small`)
- yt-dlp metadata microservice (FastAPI, deployed separately)

## Setup

```bash
flutter pub get
cp .env.example .env        # then fill in real values
flutter run
```

`.env` keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `OPENAI_API_KEY`.

## Backend

- **Migrations**: `supabase/migrations/` — apply via the Supabase SQL
  editor or `supabase db push`.
- **Edge Function**: `supabase/functions/extract-metadata` —
  `supabase functions deploy extract-metadata --no-verify-jwt`.
  Secrets: `META_OEMBED_TOKEN`, `YTDLP_SERVICE_URL`, `YTDLP_SERVICE_SECRET`.
- **yt-dlp service**: `services/ytdlp/` — deploy the Dockerfile to
  Render/Fly/Cloud Run. Powers Instagram/TikTok metadata + transcripts.
  Set `SERVICE_SECRET`; mount Instagram cookies at `/data/ig_cookies.txt`.

## Project layout

```
lib/
  core/services/    Supabase, AI, metadata, settings, share
  core/utils/       platform detection
  features/         home, search, folder, collection, add_item, auth…
  models/           stash_item, collection, smart_collection, …
supabase/           migrations + extract-metadata edge function
services/ytdlp/     FastAPI yt-dlp metadata + transcript service
```

## Security

Never commit `.env`, Instagram cookie files, or service secrets — they
are git-ignored. Use `.env.example` as the template.

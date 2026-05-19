-- Exact media duration (seconds) from yt-dlp/metadata, for the
-- video-detail screen + card duration pill. Idempotent.
ALTER TABLE public.stash_items
  ADD COLUMN IF NOT EXISTS duration_seconds integer;

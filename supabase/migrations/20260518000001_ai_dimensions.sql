-- AI multi-dimensional classification columns for stash_items.
-- Idempotent: safe to re-run.

ALTER TABLE public.stash_items
  ADD COLUMN IF NOT EXISTS primary_category text,
  ADD COLUMN IF NOT EXISTS length_bucket   text,
  ADD COLUMN IF NOT EXISTS mood            text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS intent          text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS skill_level     text,
  ADD COLUMN IF NOT EXISTS visual_style    text,
  ADD COLUMN IF NOT EXISTS creator_type    text,
  ADD COLUMN IF NOT EXISTS language        text,
  ADD COLUMN IF NOT EXISTS topics          text[] NOT NULL DEFAULT '{}';

-- Indexes that power Smart Collections + filtered search.
CREATE INDEX IF NOT EXISTS idx_stash_items_primary_category
  ON public.stash_items (user_id, primary_category);

CREATE INDEX IF NOT EXISTS idx_stash_items_length_bucket
  ON public.stash_items (user_id, length_bucket);

CREATE INDEX IF NOT EXISTS idx_stash_items_mood
  ON public.stash_items USING gin (mood);

CREATE INDEX IF NOT EXISTS idx_stash_items_intent
  ON public.stash_items USING gin (intent);

CREATE INDEX IF NOT EXISTS idx_stash_items_topics
  ON public.stash_items USING gin (topics);

CREATE INDEX IF NOT EXISTS idx_stash_items_tags
  ON public.stash_items USING gin (tags);

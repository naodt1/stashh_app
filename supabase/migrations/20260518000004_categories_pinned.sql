-- Pinned folders + freshness for the Folders redesign. Idempotent.
ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Distinguish AI auto-filed folders from user-created ones.
-- User-created folders always show (even when empty); AI-auto folders
-- only show when they have items.
ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS auto_created boolean NOT NULL DEFAULT false;

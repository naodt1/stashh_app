-- Platform source, user collections, transcript, and pgvector semantic search.
-- Idempotent.

ALTER TABLE public.stash_items
  ADD COLUMN IF NOT EXISTS platform   text,
  ADD COLUMN IF NOT EXISTS transcript text;

CREATE INDEX IF NOT EXISTS idx_stash_items_platform
  ON public.stash_items (user_id, platform);

CREATE TABLE IF NOT EXISTS public.collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  icon text DEFAULT 'collections_bookmark',
  position int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.collection_items (
  collection_id uuid NOT NULL REFERENCES public.collections(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.stash_items(id) ON DELETE CASCADE,
  added_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (collection_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_collection_items_item
  ON public.collection_items (item_id);

ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own collections" ON public.collections;
CREATE POLICY "own collections" ON public.collections
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "own collection_items" ON public.collection_items;
CREATE POLICY "own collection_items" ON public.collection_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.collections c
            WHERE c.id = collection_id AND c.user_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.collections c
            WHERE c.id = collection_id AND c.user_id = auth.uid())
  );

CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE public.stash_items
  ADD COLUMN IF NOT EXISTS embedding vector(1536);

CREATE INDEX IF NOT EXISTS idx_stash_items_embedding
  ON public.stash_items USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

CREATE OR REPLACE FUNCTION public.match_stash_items(
  query_embedding vector(1536),
  match_user_id uuid,
  match_count int DEFAULT 30,
  similarity_threshold float DEFAULT 0.15
)
RETURNS SETOF public.stash_items
LANGUAGE sql STABLE
AS $$
  SELECT *
  FROM public.stash_items
  WHERE user_id = match_user_id
    AND embedding IS NOT NULL
    AND 1 - (embedding <=> query_embedding) > similarity_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;

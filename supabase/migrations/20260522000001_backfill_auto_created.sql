-- Backfill: folders predating the auto_created column all defaulted to
-- false, so empty AI-filed folders wrongly showed as user-created.
-- Flag any folder named after an AI primary category as auto-created.
UPDATE public.categories
SET auto_created = true
WHERE name = ANY (ARRAY[
  'Fitness & Workouts','Sports','Recipes & Cooking','Finance & Money',
  'Self-Improvement / Motivation','Fashion & Beauty','Tech & Gadgets',
  'Education / Tutorials','Comedy / Memes','Edits','Animals & Pets',
  'Travel','Home & DIY','Health & Wellness','Business & Entrepreneurship',
  'Entertainment','News & Current Events','Other / Miscellaneous'
]);

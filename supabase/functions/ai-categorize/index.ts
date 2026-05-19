// Supabase Edge Function: ai-categorize
// Server-side OpenAI proxy so AI works on EVERY platform (web included)
// and the API key is never shipped in the client bundle.
//
// Deploy:  supabase functions deploy ai-categorize --no-verify-jwt
// Secret:  supabase secrets set OPENAI_API_KEY=sk-...
//
// Body: { action: "categorize", text } -> categorization JSON
//       { action: "embed",      text } -> { embedding: number[] }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
};

const PRIMARY = [
  "Fitness & Workouts", "Recipes & Cooking", "Finance & Money",
  "Self-Improvement / Motivation", "Fashion & Beauty", "Tech & Gadgets",
  "Education / Tutorials", "Comedy / Memes", "Travel", "Home & DIY",
  "Health & Wellness", "Business & Entrepreneurship", "Entertainment",
  "News & Current Events", "Other / Miscellaneous",
];
const MOODS = ["Motivational", "Relaxing", "Intense", "Funny", "Informative", "Emotional"];
const INTENTS = ["Learn", "Inspire", "Entertain", "Shop", "Remember", "Humor"];
const VISUAL = ["Talking Head", "Text-heavy", "ASMR", "Cinematic", "Screen Recording", "Unknown"];
const CREATOR = ["Influencer", "Expert", "Brand", "Friend", "Unknown"];

const SYSTEM = `You are a precise content-cataloguing AI for a personal "second brain" app.
Given whatever signal is available about a saved video/link/note (title,
description, transcript snippets, URL, creator handle), return ONLY a JSON
object with EXACTLY these keys:

{
  "primary_category": one of ${JSON.stringify(PRIMARY)},
  "title": short human title (<= 80 chars, no hashtags/emoji spam),
  "description": one concise sentence describing what it is,
  "content_type": one of ["link","video","image","text","document"],
  "length_bucket": one of ["short","medium","long","unknown"],
  "mood": subset of ${JSON.stringify(MOODS)},
  "intent": subset of ${JSON.stringify(INTENTS)},
  "skill_level": one of ["Beginner","Intermediate","Advanced"] or null,
  "visual_style": one of ${JSON.stringify(VISUAL)},
  "creator_type": one of ${JSON.stringify(CREATOR)},
  "language": the human language of the content (e.g. "English"),
  "topics": 2-6 specific semantic topics (e.g. "high-protein meals","stoic philosophy"),
  "tags": 3-6 short lowercase keywords
}

Rules:
- primary_category MUST be one of the listed values, never invent one.
- Pick the single best primary_category even if ambiguous.
- mood/intent are MULTI-label arrays; pick all that genuinely apply (>=1).
- Infer skill_level only for instructional content, else null.
- Be specific in topics — they power semantic search.
- Output strictly valid JSON, no markdown, no commentary.`;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const json = (b: unknown, status = 200) =>
    new Response(JSON.stringify(b), {
      status,
      headers: { ...cors, "Content-Type": "application/json" },
    });

  try {
    const key = Deno.env.get("OPENAI_API_KEY");
    if (!key) return json({ error: "OPENAI_API_KEY not set" }, 500);

    const { action, text } = await req.json();
    if (!text || typeof text !== "string" || !text.trim()) {
      return json({ error: "text required" }, 400);
    }
    const input = text.length > 8000 ? text.slice(0, 8000) : text;

    if (action === "embed") {
      const r = await fetch("https://api.openai.com/v1/embeddings", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify({
          model: "text-embedding-3-small",
          input,
        }),
      });
      if (!r.ok) return json({ error: `openai ${r.status}` }, 502);
      const b = await r.json();
      return json({ embedding: b.data[0].embedding });
    }

    // default: categorize
    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        max_tokens: 700,
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM },
          { role: "user", content: `Analyze and catalogue this:\n${input}` },
        ],
      }),
    });
    if (!r.ok) return json({ error: `openai ${r.status}` }, 502);
    const b = await r.json();
    const parsed = JSON.parse(b.choices[0].message.content);
    return json(parsed);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

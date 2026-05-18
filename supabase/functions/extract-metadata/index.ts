// Supabase Edge Function: extract-metadata
// Tiered link-metadata extraction. On-device scraping of IG/TikTok fails
// (login wall), so this runs server-side with the chain:
//   1. TikTok oEmbed         (public, no auth)
//   2. Instagram Graph oEmbed (needs META_OEMBED_TOKEN)
//   3. Generic Open Graph     (desktop UA scrape)
//   4. yt-dlp microservice    (needs YTDLP_SERVICE_URL + cookies)
//
// Deploy:  supabase functions deploy extract-metadata --no-verify-jwt
// Secrets: supabase secrets set META_OEMBED_TOKEN=APPID|CLIENTTOKEN \
//                                YTDLP_SERVICE_URL=https://… \
//                                YTDLP_SERVICE_SECRET=…

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

interface Meta {
  title?: string;
  description?: string;
  imageUrl?: string;
  siteName?: string;
  duration?: number; // seconds, when a tier can provide it
  transcript?: string; // captions, when yt-dlp can fetch them
  source: string; // which tier produced it (debug)
}

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/120.0 Safari/537.36";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

// Follow short links (vm.tiktok.com, instagr.am, youtu.be) to canonical URL
async function resolveRedirect(url: string): Promise<string> {
  try {
    const r = await fetch(url, {
      method: "HEAD",
      redirect: "follow",
      headers: { "User-Agent": UA },
    });
    return r.url || url;
  } catch {
    return url;
  }
}

// ── Tier 1: TikTok oEmbed ───────────────────────────────────────────────────
async function tiktokOEmbed(url: string): Promise<Meta | null> {
  try {
    const r = await fetch(
      `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`,
      { headers: { "User-Agent": UA } },
    );
    if (!r.ok) return null;
    const j = await r.json();
    if (!j.title && !j.thumbnail_url) return null;
    return {
      title: j.title ?? j.author_name,
      description: j.author_name ? `By ${j.author_name}` : undefined,
      imageUrl: j.thumbnail_url,
      siteName: "TikTok",
      source: "tiktok-oembed",
    };
  } catch {
    return null;
  }
}

// ── Tier 2: Instagram Graph oEmbed ──────────────────────────────────────────
async function instagramOEmbed(url: string): Promise<Meta | null> {
  const token = Deno.env.get("META_OEMBED_TOKEN");
  if (!token) return null;
  try {
    const ep =
      `https://graph.facebook.com/v19.0/instagram_oembed` +
      `?url=${encodeURIComponent(url)}` +
      `&fields=thumbnail_url,author_name,title` +
      `&access_token=${encodeURIComponent(token)}`;
    const r = await fetch(ep);
    if (!r.ok) return null;
    const j = await r.json();
    if (!j.thumbnail_url && !j.title) return null;
    return {
      title: j.title ?? (j.author_name ? `Instagram · ${j.author_name}` : "Instagram post"),
      description: j.author_name ? `By ${j.author_name}` : undefined,
      imageUrl: j.thumbnail_url,
      siteName: "Instagram",
      source: "instagram-oembed",
    };
  } catch {
    return null;
  }
}

// ── Tier 3: Generic Open Graph scrape ───────────────────────────────────────
function metaTag(html: string, key: string): string | undefined {
  const k = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pats = [
    new RegExp(
      `<meta[^>]+(?:property|name)\\s*=\\s*["']${k}["'][^>]*?content\\s*=\\s*["']([^"']*)["']`,
      "i",
    ),
    new RegExp(
      `<meta[^>]+content\\s*=\\s*["']([^"']*)["'][^>]*?(?:property|name)\\s*=\\s*["']${k}["']`,
      "i",
    ),
  ];
  for (const p of pats) {
    const m = html.match(p);
    if (m?.[1]?.trim()) return m[1].trim();
  }
}

async function genericOG(url: string): Promise<Meta | null> {
  try {
    const r = await fetch(url, {
      headers: {
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml",
      },
      redirect: "follow",
    });
    if (!r.ok) return null;
    const html = await r.text();
    const title =
      metaTag(html, "og:title") ??
      metaTag(html, "twitter:title") ??
      html.match(/<title[^>]*>([^<]+)<\/title>/i)?.[1]?.trim();
    const image =
      metaTag(html, "og:image") ??
      metaTag(html, "og:image:secure_url") ??
      metaTag(html, "twitter:image");
    if (!title && !image) return null;
    return {
      title,
      description:
        metaTag(html, "og:description") ?? metaTag(html, "description"),
      imageUrl: image,
      siteName: metaTag(html, "og:site_name"),
      source: "generic-og",
    };
  } catch {
    return null;
  }
}

// ── Tier 4: yt-dlp microservice ─────────────────────────────────────────────
async function ytDlp(url: string): Promise<Meta | null> {
  const base = Deno.env.get("YTDLP_SERVICE_URL");
  if (!base) return null;
  try {
    const r = await fetch(`${base.replace(/\/$/, "")}/extract`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Service-Secret": Deno.env.get("YTDLP_SERVICE_SECRET") ?? "",
      },
      body: JSON.stringify({ url }),
      signal: AbortSignal.timeout(25_000),
    });
    if (!r.ok) return null;
    const j = await r.json();
    if (!j.title && !j.thumbnail) return null;
    return {
      title: j.title,
      description: j.uploader ? `By ${j.uploader}` : j.description,
      imageUrl: j.thumbnail,
      siteName: j.extractor,
      duration: typeof j.duration === "number" ? j.duration : undefined,
      transcript: typeof j.transcript === "string" ? j.transcript : undefined,
      source: "yt-dlp",
    };
  } catch {
    return null;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { url } = await req.json();
    if (!url || typeof url !== "string") {
      return new Response(JSON.stringify({ error: "url required" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const canonical = await resolveRedirect(url);
    const host = (() => {
      try {
        return new URL(canonical).hostname.toLowerCase();
      } catch {
        return "";
      }
    })();

    const isTT = host.includes("tiktok.com");
    const isIG = host.includes("instagram.com");

    // Order the chain by host so we hit the most reliable source first
    const chain: Array<() => Promise<Meta | null>> = [];
    if (isTT) chain.push(() => tiktokOEmbed(canonical));
    if (isIG) chain.push(() => instagramOEmbed(canonical));
    chain.push(() => genericOG(canonical));
    if (isTT || isIG) chain.push(() => ytDlp(canonical)); // last resort

    let meta: Meta | null = null;
    for (const step of chain) {
      meta = await step();
      if (meta && (meta.title || meta.imageUrl)) break;
    }

    return new Response(
      JSON.stringify(meta ?? { source: "none" }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});

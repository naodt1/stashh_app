"""
yt-dlp metadata microservice (Tier 4 fallback for Instagram / TikTok).

Metadata only — no media is ever downloaded. Returns title, thumbnail,
uploader, description, extractor.

Run:    uvicorn main:app --host 0.0.0.0 --port 8080
Secret: set SERVICE_SECRET; the Edge Function sends it as X-Service-Secret.
Cookies: mount Netscape cookies.txt files (see README / setup notes):
         IG_COOKIES=/data/ig_cookies.txt   TT_COOKIES=/data/tt_cookies.txt
"""

import os
import re
import urllib.request
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel
from yt_dlp import YoutubeDL


def _strip_vtt(vtt: str) -> str:
    """Turn a WEBVTT/SRT caption blob into plain transcript text."""
    lines = []
    for ln in vtt.splitlines():
        ln = ln.strip()
        if (
            not ln
            or ln == "WEBVTT"
            or "-->" in ln
            or ln.isdigit()
            or ln.startswith(("Kind:", "Language:", "NOTE"))
        ):
            continue
        ln = re.sub(r"<[^>]+>", "", ln)  # inline timing tags
        lines.append(ln)
    # de-dupe consecutive repeats (auto-caption artifact)
    out = []
    for ln in lines:
        if not out or out[-1] != ln:
            out.append(ln)
    return " ".join(out)[:6000]


def _fetch_transcript(info: dict) -> str | None:
    """Prefer real subtitles, fall back to auto-captions (English)."""
    for key in ("subtitles", "automatic_captions"):
        tracks = info.get(key) or {}
        for lang in ("en", "en-US", "en-GB", *tracks.keys()):
            entries = tracks.get(lang)
            if not entries:
                continue
            ent = next(
                (e for e in entries if e.get("ext") in ("vtt", "srv1", "srt")),
                entries[0],
            )
            try:
                with urllib.request.urlopen(ent["url"], timeout=10) as r:
                    text = _strip_vtt(r.read().decode("utf-8", "ignore"))
                if len(text) > 40:
                    return text
            except Exception:
                continue
    return None

app = FastAPI()

SERVICE_SECRET = os.environ.get("SERVICE_SECRET", "")
IG_COOKIES = os.environ.get("IG_COOKIES", "")  # path to cookies.txt
TT_COOKIES = os.environ.get("TT_COOKIES", "")
PROXY = os.environ.get("YTDLP_PROXY", "")       # optional, e.g. http://user:pass@host:port


class ExtractReq(BaseModel):
    url: str


# Recommended base flags — fast, metadata-only, resilient.
def _base_opts() -> dict:
    opts = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,        # never pull the video
        "noplaylist": True,           # single item only
        "writesubtitles": True,       # expose caption track URLs
        "writeautomaticsub": True,    # …and auto-generated ones
        "subtitleslangs": ["en.*"],
        "extract_flat": False,        # we need the full info dict (thumbnail/title)
        "socket_timeout": 15,
        "retries": 2,
        "nocheckcertificate": True,
        "http_headers": {
            "User-Agent": (
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                "AppleWebKit/605.1.15 (KHTML, like Gecko) "
                "Version/17.0 Mobile/15E148 Safari/604.1"
            )
        },
    }
    if PROXY:
        opts["proxy"] = PROXY
    return opts


def _cookies_for(url: str) -> str | None:
    u = url.lower()
    if "instagram.com" in u and IG_COOKIES and os.path.exists(IG_COOKIES):
        return IG_COOKIES
    if "tiktok.com" in u and TT_COOKIES and os.path.exists(TT_COOKIES):
        return TT_COOKIES
    return None


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/extract")
def extract(req: ExtractReq, x_service_secret: str = Header(default="")):
    if SERVICE_SECRET and x_service_secret != SERVICE_SECRET:
        raise HTTPException(status_code=401, detail="bad secret")

    opts = _base_opts()
    cookie_file = _cookies_for(req.url)
    if cookie_file:
        opts["cookiefile"] = cookie_file

    try:
        with YoutubeDL(opts) as ydl:
            info = ydl.extract_info(req.url, download=False)
    except Exception as e:
        # Surface a soft failure — Edge Function falls back gracefully.
        return {"error": str(e)[:300]}

    if not info:
        return {"error": "no info"}

    # Pick the best thumbnail (highest resolution available).
    thumb = info.get("thumbnail")
    thumbs = info.get("thumbnails") or []
    if thumbs:
        best = max(
            thumbs,
            key=lambda t: (t.get("height") or 0) * (t.get("width") or 0),
        )
        thumb = best.get("url") or thumb

    return {
        "title": info.get("title") or info.get("description", "")[:80] or None,
        "thumbnail": thumb,
        "uploader": info.get("uploader") or info.get("uploader_id"),
        "description": (info.get("description") or "")[:500] or None,
        "transcript": _fetch_transcript(info),
        "extractor": info.get("extractor_key"),
        "duration": info.get("duration"),
        "webpage_url": info.get("webpage_url"),
    }

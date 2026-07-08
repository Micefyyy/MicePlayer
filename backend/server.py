"""
FastAPI server that:
1. Proxies search to AniList GraphQL (same as the web app)
2. Serves HLS .m3u8 and .ts files
3. Provides episode stream metadata for the iOS player
4. Serves the web frontend for local testing
"""

import asyncio
import os
import re
import json
from pathlib import Path
from urllib.parse import urljoin, quote
from fastapi import FastAPI, HTTPException, Request
from starlette.responses import Response, StreamingResponse
from fastapi.responses import FileResponse, RedirectResponse, Response
from fastapi.middleware.cors import CORSMiddleware
import httpx
import scraper

app = FastAPI(title="Anime HLS API")

_episode_title_cache: dict[int, dict[int, str]] = {}
_episode_count_cache: dict[int, tuple[int | None, int | None]] = {}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

ANILIST_URL = "https://graphql.anilist.co"
CONTENT_DIR = Path(os.environ.get("CONTENT_DIR", "./content"))

ANIQUERY = """
query ($page: Int, $perPage: Int, $type: MediaType, $sort: [MediaSort]) {
  Page(page: $page, perPage: $perPage) {
    media(type: $type, sort: $sort) {
      id title { romaji english }
      coverImage { large extraLarge }
      bannerImage
      episodes duration status
      genres
      averageScore
      season seasonYear
      studios { nodes { name } }
    }
  }
}
"""

SEARCHQUERY = """
query ($search: String) {
  Page(perPage: 30) {
    media(search: $search, type: ANIME) {
      id title { romaji english }
      coverImage { large extraLarge }
      episodes duration status
      genres
      averageScore
      season seasonYear
    }
  }
}
"""

def format_anime(media: dict) -> dict:
    title = media.get("title", {})
    studios = media.get("studios", {}).get("nodes", [])
    return {
        "id": media["id"],
        "title_romaji": title.get("romaji", ""),
        "title_english": title.get("english"),
        "synopsis": media.get("description", ""),
        "cover_image_large": media.get("coverImage", {}).get("extraLarge"),
        "cover_image_medium": media.get("coverImage", {}).get("large"),
        "banner_image": media.get("bannerImage"),
        "score": media.get("averageScore"),
        "episodes": media.get("episodes"),
        "status": media.get("status"),
        "genres": media.get("genres"),
        "studio": studios[0].get("name") if studios else None,
        "year": media.get("seasonYear"),
        "season": media.get("season"),
    }


@app.get("/")
async def root():
    from starlette.responses import RedirectResponse
    return RedirectResponse(url="/web/")


@app.get("/api/trending")
async def get_trending():
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.post(ANILIST_URL, json={
                "query": ANIQUERY,
                "variables": {"page": 1, "perPage": 20, "type": "ANIME", "sort": ["TRENDING_DESC"]}
            })
            r.raise_for_status()
            data = r.json()
        return [format_anime(m) for m in data.get("data", {}).get("Page", {}).get("media", [])]
    except Exception:
        return []


@app.get("/api/seasonal")
async def get_seasonal():
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.post(ANILIST_URL, json={
                "query": ANIQUERY,
                "variables": {"page": 1, "perPage": 20, "type": "ANIME", "sort": ["POPULARITY_DESC"]}
            })
            r.raise_for_status()
            data = r.json()
        return [format_anime(m) for m in data.get("data", {}).get("Page", {}).get("media", [])]
    except Exception:
        return []


@app.get("/api/popular")
async def get_popular():
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.post(ANILIST_URL, json={
                "query": ANIQUERY,
                "variables": {"page": 1, "perPage": 20, "type": "ANIME", "sort": ["POPULARITY_DESC"]}
            })
            r.raise_for_status()
            data = r.json()
        return [format_anime(m) for m in data.get("data", {}).get("Page", {}).get("media", [])]
    except Exception:
        return []


@app.get("/api/search")
async def search_anime(q: str):
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.post(ANILIST_URL, json={
                "query": SEARCHQUERY,
                "variables": {"search": q}
            })
            r.raise_for_status()
            data = r.json()
        return [format_anime(m) for m in data.get("data", {}).get("Page", {}).get("media", [])]
    except Exception:
        return []


@app.get("/api/anime/{anime_id}")
async def get_anime(anime_id: int):
    query = """
    query ($id: Int) {
      Media(id: $id, type: ANIME) {
        id title { romaji english }
        coverImage { large extraLarge }
        episodes duration status description
        genres averageScore season seasonYear
        studios { nodes { name } }
      }
    }
    """
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.post(ANILIST_URL, json={
                "query": query,
                "variables": {"id": anime_id}
            })
            r.raise_for_status()
            data = r.json()
        media = data.get("data", {}).get("Media")
        if not media:
            raise HTTPException(404, "Anime not found")
        return format_anime(media)
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(502, "Failed to fetch anime data")


@app.get("/api/anime/{anime_id}/episodes")
async def get_episodes(anime_id: int):
    """
    Returns episode list for an anime.
    Fast path: AniList total count (instant) + background Jikan titles.
    Fallback: miruro.tv scrape (slow).
    """
    anilist_total = None
    mal_id = None

    if anime_id in _episode_count_cache:
        anilist_total, mal_id = _episode_count_cache[anime_id]
    else:
        query = """
        query ($id: Int) {
          Media(id: $id, type: ANIME) {
            episodes
            idMal
          }
        }
        """
        try:
            async with httpx.AsyncClient(timeout=10) as c:
                r = await c.post(ANILIST_URL, json={"query": query, "variables": {"id": anime_id}})
                r.raise_for_status()
                media = r.json().get("data", {}).get("Media", {})
                anilist_total = media.get("episodes")
                mal_id = media.get("idMal")
                _episode_count_cache[anime_id] = (anilist_total, mal_id)
        except Exception:
            pass

    if not anilist_total:
        async with httpx.AsyncClient(timeout=10) as client:
            episodes = await scraper.get_miruro_episodes(anime_id, client)
        if episodes:
            anilist_total = len(episodes)
            _episode_count_cache[anime_id] = (anilist_total, mal_id)

    if not anilist_total:
        async with httpx.AsyncClient(timeout=15) as client:
            slug = await scraper.get_anineko_slug(anime_id, client)
            if slug:
                anilist_total = await scraper.get_anineko_episode_count(slug, client)
                if anilist_total:
                    _episode_count_cache[anime_id] = (anilist_total, mal_id)

    if not anilist_total:
        return [{"id": 1, "number": 1, "title": "Episode 1", "thumbnail": None, "duration": 1440}]

    episodes = [{"number": i, "title": f"Episode {i}"} for i in range(1, anilist_total + 1)]

    if anime_id in _episode_title_cache:
        jikan_titles = _episode_title_cache[anime_id]
        for ep in episodes:
            if ep["number"] in jikan_titles:
                ep["title"] = jikan_titles[ep["number"]]
    elif mal_id:
        async def _fetch_jikan_titles(aid, mid):
            try:
                titles = {}
                page = 1
                async with httpx.AsyncClient(timeout=10) as jc:
                    while page <= 5:
                        if page > 1:
                            await asyncio.sleep(0.4)
                        jr = await jc.get(f"https://api.jikan.moe/v4/anime/{mid}/episodes?page={page}", timeout=10)
                        if jr.status_code == 429:
                            await asyncio.sleep(2)
                            continue
                        if jr.status_code != 200:
                            break
                        jdata = jr.json()
                        for ep in jdata.get("data", []):
                            num = ep.get("mal_id") or ep.get("number")
                            title = ep.get("title", "")
                            if num and title:
                                titles[num] = title
                        if not jdata.get("pagination", {}).get("has_next_page", False):
                            break
                        page += 1
                if titles:
                    _episode_title_cache[aid] = titles
            except Exception:
                pass
        asyncio.create_task(_fetch_jikan_titles(anime_id, mal_id))

    return [
        {"id": ep["number"], "number": ep["number"], "title": ep["title"], "thumbnail": None, "duration": 1440}
        for ep in episodes
    ]


@app.get("/api/anime/{anime_id}/episode/{episode_num}/stream")
async def get_stream(anime_id: int, episode_num: int):
    """
    Returns HLS manifest URLs for a specific episode.
    Scrapes from anineko.to, falls back to local files or test stream.
    """
    server_url = os.environ.get("STREAM_SERVER_URL", "http://10.0.0.211:8000")

    # Check if local HLS files exist
    local_dir = CONTENT_DIR / str(anime_id) / str(episode_num)
    has_local = local_dir.exists() and any(local_dir.rglob("*.m3u8"))

    if has_local:
        return {
            "sources": [
                {"quality": "360p", "manifest_url": f"{server_url}/hls/{anime_id}/{episode_num}/360p/playlist.m3u8"},
                {"quality": "480p", "manifest_url": f"{server_url}/hls/{anime_id}/{episode_num}/480p/playlist.m3u8"},
                {"quality": "720p", "manifest_url": f"{server_url}/hls/{anime_id}/{episode_num}/720p/playlist.m3u8"},
                {"quality": "1080p", "manifest_url": f"{server_url}/hls/{anime_id}/{episode_num}/1080p/playlist.m3u8"},
            ],
            "subtitles": [
                {"url": f"{server_url}/subs/{anime_id}/{episode_num}/en.vtt", "language": "English"}
            ]
        }

    # Try scraping from anineko.to
    async with httpx.AsyncClient(timeout=30) as client:
        slug = await scraper.get_anineko_slug(anime_id, client)
        if slug:
            stream = await scraper.get_stream_url(slug, episode_num, client)
            if stream:
                result = {"sub": [], "dub": [], "subtitles": []}
                if stream.get("sub"):
                    result["sub"].append({"quality": "Auto", "manifest_url": stream["sub"]["manifest_url"]})
                    if stream["sub"].get("subtitle_url"):
                        result["subtitles"].append({"url": stream["sub"]["subtitle_url"], "language": "English"})
                if stream.get("dub"):
                    result["dub"].append({"quality": "Auto", "manifest_url": stream["dub"]["manifest_url"]})
                return result

    # Fallback: test stream
    return {
        "sources": [
            {"quality": "720p", "manifest_url": "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"},
        ],
        "subtitles": []
    }


@app.get("/hls/{anime_id}/{episode_num}/{quality}/{file_name:path}")
async def serve_hls(anime_id: int, episode_num: int, quality: str, file_name: str):
    """Serve .m3u8 and .ts files from the local content directory."""
    file_path = CONTENT_DIR / str(anime_id) / str(episode_num) / quality / file_name
    if not file_path.exists():
        raise HTTPException(404, "File not found")
    return FileResponse(str(file_path), media_type={
        ".m3u8": "application/vnd.apple.mpegurl",
        ".ts": "video/mp2t",
    }.get(file_path.suffix, "application/octet-stream"))


_proxy_client = None

def get_proxy_client():
    global _proxy_client
    if _proxy_client is None:
        _proxy_client = httpx.AsyncClient(timeout=30, follow_redirects=True, limits=httpx.Limits(max_connections=50, max_keepalive_connections=20))
    return _proxy_client


@app.api_route("/proxy", methods=["GET", "HEAD"])
async def proxy_stream(request: Request, url: str):
    if not url:
        raise HTTPException(400, "Missing url parameter")

    client = get_proxy_client()

    try:
        r = await client.get(url, headers=scraper.HEADERS)
    except Exception as e:
        raise HTTPException(502, f"Upstream error: {e}")

    if r.status_code != 200:
        raise HTTPException(r.status_code, "Upstream returned error")

    content_type = r.headers.get("content-type", "")

    # If it's an m3u8 playlist, rewrite relative URLs to go through proxy
    if "mpegurl" in content_type.lower() or url.endswith(".m3u8") or ".m3u8?" in url:
        text = r.text
        base_url = url.rsplit("/", 1)[0] + "/"
        lines = text.split("\n")
        rewritten = []
        for line in lines:
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                absolute = urljoin(base_url, stripped)
                rewritten.append(f"/proxy?url={quote(absolute, safe='')}")
            elif stripped.startswith("#EXT-X-MAP:URI="):
                uri_match = re.search(r'URI="([^"]+)"', stripped)
                if uri_match:
                    absolute = urljoin(base_url, uri_match.group(1))
                    rewritten.append(stripped.replace(uri_match.group(1), f"/proxy?url={quote(absolute, safe='')}")
                else:
                    rewritten.append(stripped)
            else:
                rewritten.append(stripped)
        return Response(
            content="\n".join(rewritten),
            media_type="application/vnd.apple.mpegurl",
            headers={"Access-Control-Allow-Origin": "*"},
        )

    # Stream .ts segments instead of buffering full response in memory
    async def stream_segments():
        async with client.stream("GET", url, headers=scraper.HEADERS) as upstream:
            async for chunk in upstream.aiter_bytes(65536):
                yield chunk

    return StreamingResponse(
        stream_segments(),
        media_type=content_type or "application/octet-stream",
        headers={"Access-Control-Allow-Origin": "*"},
    )

    # Otherwise stream raw (for .ts segments, subtitles, etc.)
    return Response(
        content=r.content,
        media_type=content_type or "application/octet-stream",
        headers={"Access-Control-Allow-Origin": "*"},
    )


# Web frontend static files
WEB_DIR = Path(__file__).parent.parent / "web"

@app.get("/favicon.ico")
async def favicon():
    return Response(content=b"", media_type="image/x-icon")

@app.get("/web")
async def serve_web_redirect():
    return RedirectResponse(url="/web/")

@app.get("/web/")
async def serve_web_index():
    index = WEB_DIR / "index.html"
    if index.exists():
        resp = FileResponse(str(index), media_type="text/html")
        resp.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        resp.headers["Pragma"] = "no-cache"
        resp.headers["Expires"] = "0"
        return resp
    raise HTTPException(404, "Web frontend not found")

@app.get("/web/{file_path:path}")
async def serve_web_static(file_path: str):
    file = WEB_DIR / file_path
    if file.exists() and file.is_file():
        media_types = {".html": "text/html", ".css": "text/css", ".js": "application/javascript"}
        resp = FileResponse(str(file), media_type=media_types.get(file.suffix, "application/octet-stream"))
        resp.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        resp.headers["Pragma"] = "no-cache"
        resp.headers["Expires"] = "0"
        return resp
    raise HTTPException(404, "File not found")


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

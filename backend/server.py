"""
FastAPI server that:
1. Proxies search to AniList GraphQL (same as the web app)
2. Serves HLS .m3u8 and .ts files
3. Provides episode stream metadata for the iOS player
"""

import os
import json
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import httpx

app = FastAPI(title="Anime HLS API")

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
    return {"status": "ok", "message": "Anime iOS backend is running"}


@app.get("/api/trending")
async def get_trending():
    async with httpx.AsyncClient(timeout=15) as client:
        r = await client.post(ANILIST_URL, json={
            "query": ANIQUERY,
            "variables": {"page": 1, "perPage": 20, "type": "ANIME", "sort": ["TRENDING_DESC"]}
        })
        r.raise_for_status()
        data = r.json()
    return [format_anime(m) for m in data.get("data", {}).get("Page", {}).get("media", [])]


@app.get("/api/seasonal")
async def get_seasonal():
    async with httpx.AsyncClient(timeout=15) as client:
        r = await client.post(ANILIST_URL, json={
            "query": ANIQUERY,
            "variables": {"page": 1, "perPage": 20, "type": "ANIME", "sort": ["POPULARITY_DESC"]}
        })
        r.raise_for_status()
        data = r.json()
    return [format_anime(m) for m in data.get("data", {}).get("Page", {}).get("media", [])]


@app.get("/api/popular")
async def get_popular():
    async with httpx.AsyncClient(timeout=15) as client:
        r = await client.post(ANILIST_URL, json={
            "query": ANIQUERY,
            "variables": {"page": 1, "perPage": 20, "type": "ANIME", "sort": ["POPULARITY_DESC"]}
        })
        r.raise_for_status()
        data = r.json()
    return [format_anime(m) for m in data.get("data", {}).get("Page", {}).get("media", [])]


@app.get("/api/search")
async def search_anime(q: str):
    async with httpx.AsyncClient(timeout=15) as client:
        r = await client.post(ANILIST_URL, json={
            "query": SEARCHQUERY,
            "variables": {"search": q}
        })
        r.raise_for_status()
        data = r.json()
    return [format_anime(m) for m in data.get("data", {}).get("Page", {}).get("media", [])]


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


@app.get("/api/anime/{anime_id}/episodes")
async def get_episodes(anime_id: int):
    """
    Returns episode list for an anime.
    In production, this would come from a database or scraping service.
    For now returns placeholder episodes 1-N where N comes from AniList.
    """
    query = """
    query ($id: Int) {
      Media(id: $id, type: ANIME) {
        episodes
      }
    }
    """
    async with httpx.AsyncClient(timeout=15) as client:
        r = await client.post(ANILIST_URL, json={
            "query": query,
            "variables": {"id": anime_id}
        })
        r.raise_for_status()
        data = r.json()
    total = data.get("data", {}).get("Media", {}).get("episodes") or 12
    return [
        {"id": i, "number": i, "title": f"Episode {i}", "thumbnail": None, "duration": 1440}
        for i in range(1, total + 1)
    ]


@app.get("/api/anime/{anime_id}/episode/{episode_num}/stream")
async def get_stream(anime_id: int, episode_num: int):
    """
    Returns HLS manifest URLs for a specific episode.
    In production these would point to the transcoded HLS files on your CDN.
    """
    server_url = os.environ.get("STREAM_SERVER_URL", "http://localhost:8000")
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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

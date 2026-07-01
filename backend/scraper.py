import re
import asyncio
from urllib.parse import quote, urljoin

import httpx
from bs4 import BeautifulSoup

# Cloudscraper-style headers to bypass basic bot detection
HEADERS = {
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}

BASE = "https://anineko.to"

# Simple in-memory cache: anime_id -> slug
_slug_cache = {}

async def search_slug(title: str, client: httpx.AsyncClient) -> str | None:
    """Search anineko for an anime by title and return its slug."""
    clean = re.sub(r"[\(\[].*?[\)\]]", "", title).strip()
    url = f"{BASE}/browser?keyword={quote(clean[:60])}"
    r = await client.get(url, headers=HEADERS, follow_redirects=True, timeout=15)
    if r.status_code != 200:
        return None
    soup = BeautifulSoup(r.text, "html.parser")
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if href.startswith("/watch/") and "/ep-" not in href:
            link_text = a.get_text(strip=True).lower()
            query_lower = clean.lower()
            if query_lower in link_text or any(
                word in link_text for word in query_lower.split()[:3]
            ):
                return href.replace("/watch/", "")
    return None

async def get_slug_for_anilist(anime_id: int, client: httpx.AsyncClient) -> str | None:
    """Get the anineko slug for an AniList anime ID, with caching."""
    if anime_id in _slug_cache:
        return _slug_cache[anime_id]

    # Fetch the anime title from AniList
    query = """
    query ($id: Int) {
      Media(id: $id, type: ANIME) {
        title { romaji english }
      }
    }
    """
    r = await client.post(
        "https://graphql.anilist.co",
        json={"query": query, "variables": {"id": anime_id}},
        timeout=10,
    )
    if r.status_code != 200:
        return None
    data = r.json().get("data", {}).get("Media", {})
    title = data.get("title", {})
    candidates = [title.get("romaji"), title.get("english")]

    slug = None
    for t in candidates:
        if t:
            slug = await search_slug(t, client)
            if slug:
                break

    _slug_cache[anime_id] = slug
    return slug

async def get_stream_url(slug: str, episode_num: int, client: httpx.AsyncClient) -> dict | None:
    """
    Scrape the episode page on anineko and return the HLS stream URL.
    Returns {"manifest_url": str, "server": str, "subtitle_url": str | None} or None.
    """
    ep_url = f"{BASE}/watch/{slug}/ep-{episode_num}"
    r = await client.get(ep_url, headers=HEADERS, follow_redirects=True, timeout=15)
    if r.status_code != 200:
        return None

    # Extract data-video attributes (vivibebe/bibiemb servers)
    soup = BeautifulSoup(r.text, "html.parser")
    video_urls = []
    for el in soup.find_all(attrs={"data-video": True}):
        video_urls.append(el["data-video"])

    # Try vivibebe server first (simplest to extract m3u8)
    for url in video_urls:
        if "vivibebe" in url:
            embed = await client.get(url, headers=HEADERS, follow_redirects=True, timeout=15)
            if embed.status_code != 200:
                continue
            # Find any .m3u8 URL in the response
            m3u8_matches = re.findall(r'(https?://[^"\'<> ]+\.m3u8[^"\'<> ]*)', embed.text)
            if m3u8_matches:
                m3u8_url = m3u8_matches[0]
                # Extract subtitle URL if present
                sub_url = None
                sub_match = re.search(r'sub=([^&\s"]+)', url)
                if sub_match:
                    sub_url = sub_match.group(1)
                return {"manifest_url": m3u8_url, "subtitle_url": sub_url}
    return None

async def get_episode_list(slug: str, client: httpx.AsyncClient) -> list[dict]:
    """Get episode list from anineko for a given slug."""
    watch_url = f"{BASE}/watch/{slug}"
    r = await client.get(watch_url, headers=HEADERS, follow_redirects=True, timeout=15)
    if r.status_code != 200:
        return []
    seen = set()
    episodes = []
    soup = BeautifulSoup(r.text, "html.parser")
    for a in soup.find_all("a", href=True):
        href = a["href"]
        ep_match = re.search(r"/ep-(\d+)$", href)
        if ep_match:
            ep_num = int(ep_match.group(1))
            if ep_num not in seen:
                seen.add(ep_num)
                text_parts = a.get_text(strip=True).split("\n")
                title = text_parts[-1].strip() if len(text_parts) > 1 else f"Episode {ep_num}"
                episodes.append({"number": ep_num, "title": title})
    return sorted(episodes, key=lambda x: x["number"])

import re
import subprocess
from urllib.parse import quote, urljoin

import httpx
from bs4 import BeautifulSoup

HEADERS = {
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}

ANINEKO_BASE = "https://anineko.to"
MIRURO_BASE = "https://www.miruro.tv"

_slug_cache: dict[int, str | None] = {}
_miruro_episode_cache: dict[int, list[dict]] = {}


async def get_miruro_episodes(anime_id: int, client: httpx.AsyncClient) -> list[dict]:
    """Get episode list from miruro.tv info page by AniList ID."""
    if anime_id in _miruro_episode_cache:
        return _miruro_episode_cache[anime_id]

    try:
        r = await client.get(
            f"{MIRURO_BASE}/info/{anime_id}",
            headers=HEADERS,
            follow_redirects=True,
            timeout=15,
        )
        if r.status_code != 200:
            return []

        html = r.text

        ep_count = 0
        ld_match = re.search(r'"numberOfEpisodes":\s*(\d+)', html)
        if ld_match:
            ep_count = int(ld_match.group(1))

        if ep_count == 0:
            return []

        episodes = [
            {"number": i, "title": f"Episode {i}"}
            for i in range(1, ep_count + 1)
        ]

        _miruro_episode_cache[anime_id] = episodes
        return episodes

    except Exception:
        return []


async def search_anineko_slug(title: str, client: httpx.AsyncClient) -> str | None:
    """Search anineko.to for an anime by title and return its slug."""
    clean = re.sub(r"[\(\[].*?[\)\]]", "", title).strip().lower()
    url = f"{ANINEKO_BASE}/browser?keyword={quote(clean[:60])}"
    r = await client.get(url, headers=HEADERS, follow_redirects=True, timeout=15)
    if r.status_code != 200:
        return None

    soup = BeautifulSoup(r.text, "html.parser")
    candidates: dict[str, str] = {}

    for a in soup.find_all("a", href=True):
        href = a["href"]
        if href.startswith("/watch/") and "/ep-" not in href:
            slug = href.replace("/watch/", "")
            text = a.get_text(strip=True).lower()
            if any(w in text for w in clean.split()[:3]):
                if slug not in candidates:
                    candidates[slug] = a.get_text(strip=True)

    if not candidates:
        return None

    for slug, text in candidates.items():
        if slug.replace("-", " ") == clean or text.lower().strip() == clean:
            return slug

    return next(iter(candidates))


async def get_anineko_slug(anime_id: int, client: httpx.AsyncClient) -> str | None:
    """Get the anineko slug for an AniList anime ID, with caching."""
    if anime_id in _slug_cache:
        return _slug_cache[anime_id]

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
            slug = await search_anineko_slug(t, client)
            if slug:
                break

    _slug_cache[anime_id] = slug
    return slug


def _decode_packed_js(html: str) -> str | None:
    """Decode eval(function(p,a,c,k,e,d){...}) packed JavaScript."""
    match = re.search(
        r"eval\(function\(p,a,c,k,e,d\)\{.*?\}\('(.+?)',(\d+),(\d+),'([^']+)'\.split",
        html,
        re.DOTALL,
    )
    if not match:
        return None
    p, a, c, k = match.group(1), int(match.group(2)), int(match.group(3)), match.group(4)
    k_list = k.split("|")
    try:
        result = subprocess.run(
            [
                "node", "-e",
                f"var p={repr(p)};var a={a};var c={c};var k={repr(k_list)};"
                f"while(c--)if(k[c])p=p.replace(new RegExp('\\\\b'+c.toString({a})+'\\\\b','g'),k[c]);"
                f"console.log(p);"
            ],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            return result.stdout
    except Exception:
        pass
    return None


def _extract_stream_from_decoded(decoded: str, embed_url: str) -> str | None:
    """Extract m3u8 URL from decoded otakuhg/otakuvid JS."""
    links_match = re.search(r'var links\s*=\s*(\{[^}]+\})', decoded)
    if links_match:
        import json
        try:
            links = json.loads(links_match.group(1))
            # Prefer hls2 (authenticated), then hls4 (relative), then hls3
            for key in ["hls2", "hls4", "hls3"]:
                url = links.get(key)
                if url:
                    if url.startswith("/"):
                        origin = embed_url.split("/e/")[0]
                        url = origin + url
                    return url
        except json.JSONDecodeError:
            pass

    # Fallback: find m3u8 URLs directly
    m3u8s = re.findall(r'(https?://[^"\'<> ]+\.m3u8[^"\'<> ]*)', decoded)
    if m3u8s:
        return m3u8s[0]

    return None


async def _get_otakuhg_stream(embed_url: str, client: httpx.AsyncClient) -> str | None:
    """Fetch an otakuhg embed page and extract the stream URL by decoding packed JS."""
    r = await client.get(embed_url, headers=HEADERS, follow_redirects=True, timeout=15)
    if r.status_code != 200:
        return None

    decoded = _decode_packed_js(r.text)
    if decoded:
        return _extract_stream_from_decoded(decoded, embed_url)

    # Fallback: try direct m3u8 extraction
    m3u8s = re.findall(r'(https?://[^"\'<> ]+\.m3u8[^"\'<> ]*)', r.text)
    return m3u8s[0] if m3u8s else None


async def get_anineko_episode_count(slug: str, client: httpx.AsyncClient) -> int | None:
    """Get total episode count by scraping the anineko watch page for max ep-N link."""
    try:
        r = await client.get(
            f"{ANINEKO_BASE}/watch/{slug}",
            headers=HEADERS,
            follow_redirects=True,
            timeout=15,
        )
        if r.status_code != 200:
            return None
        ep_nums = [int(m) for m in re.findall(r"/ep-(\d+)", r.text)]
        return max(ep_nums) if ep_nums else None
    except Exception:
        return None


async def get_stream_url(slug: str, episode_num: int, client: httpx.AsyncClient) -> dict | None:
    """
    Scrape the episode page on anineko and return HLS stream URLs for sub and dub.
    Uses otakuhg as primary source (real video TS segments).
    Falls back to vivibebe (may have anti-bot issues).
    """
    ep_url = f"{ANINEKO_BASE}/watch/{slug}/ep-{episode_num}"
    r = await client.get(ep_url, headers=HEADERS, follow_redirects=True, timeout=15)
    if r.status_code != 200:
        return None

    soup = BeautifulSoup(r.text, "html.parser")
    sub_urls = []
    dub_urls = []

    for el in soup.find_all(attrs={"data-video": True}):
        url = el["data-video"]
        label = el.get_text(strip=True).lower()
        if "dub" in label:
            dub_urls.append(url)
        else:
            sub_urls.append(url)

    result = {"sub": None, "dub": None}

    # Try otakuhg first (real TS video)
    for url in sub_urls:
        if "otakuhg" in url:
            m3u8 = await _get_otakuhg_stream(url, client)
            if m3u8:
                sub_match = re.search(r'(?:sub|caption_1)=([^&\s"]+)', url)
                result["sub"] = {
                    "manifest_url": m3u8,
                    "subtitle_url": sub_match.group(1) if sub_match else None,
                }
                break

    for url in dub_urls:
        if "otakuhg" in url:
            m3u8 = await _get_otakuhg_stream(url, client)
            if m3u8:
                result["dub"] = {"manifest_url": m3u8}
                break

    # Fallback to vivibebe
    if not result["sub"]:
        for url in sub_urls:
            if "vivibebe" in url:
                embed = await client.get(url, headers=HEADERS, follow_redirects=True, timeout=15)
                if embed.status_code == 200:
                    matches = re.findall(r'(https?://[^"\'<> ]+\.m3u8[^"\'<> ]*)', embed.text)
                    if matches:
                        sub_match = re.search(r'(?:sub|caption_1)=([^&\s"]+)', url)
                        result["sub"] = {
                            "manifest_url": matches[0],
                            "subtitle_url": sub_match.group(1) if sub_match else None,
                        }
                        break

    if not result["dub"]:
        for url in dub_urls:
            if "vivibebe" in url:
                embed = await client.get(url, headers=HEADERS, follow_redirects=True, timeout=15)
                if embed.status_code == 200:
                    matches = re.findall(r'(https?://[^"\'<> ]+\.m3u8[^"\'<> ]*)', embed.text)
                    if matches:
                        result["dub"] = {"manifest_url": matches[0]}
                        break

    if result["sub"] or result["dub"]:
        return result
    return None

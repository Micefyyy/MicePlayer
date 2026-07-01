import cloudscraper, re, json
from bs4 import BeautifulSoup

scraper = cloudscraper.create_scraper()
base = "https://gogoanime3.co"

# Step 1: Search for Death Note (Anilist ID 1535)
r = scraper.get(f"{base}/search.html?keyword=Death%20Note", timeout=15)
soup = BeautifulSoup(r.text, "html.parser")
results = soup.select("div.last_episode a[href*='category']")
print(f"Search results: {len(results)}")
for a in results[:5]:
    href = a.get("href")
    title = a.get("title", "")
    print(f"  {title} -> {href}")

# Step 2: Get the anime page
if results:
    slug = results[0]["href"].replace("/category/", "")
    print(f"\nSlug: {slug}")
    
    # Step 3: Get episode page
    ep_url = f"{base}/{slug}-episode-1"
    print(f"Episode URL: {ep_url}")
    r = scraper.get(ep_url, timeout=15)
    soup = BeautifulSoup(r.text, "html.parser")
    
    # Look for video sources / iframes
    iframes = soup.find_all("iframe")
    print(f"Iframes: {len(iframes)}")
    for iframe in iframes:
        print(f"  iframe src: {iframe.get('src')}")
    
    # Look for download links
    download_links = soup.select("a[href*='download']")
    print(f"Download links: {len(download_links)}")
    
    # Look for the video element or player
    video_els = soup.select("[data-video], [data-url], .video-content, .play-video, #video-container")
    print(f"Video els: {len(video_els)}")
    for el in video_els:
        print(f"  {el.name}: {el.get('data-video', el.get('data-url', 'no-data'))}")
    
    # Print all script content for analysis
    scripts = soup.find_all("script")
    for script in scripts:
        if script.string and ("video" in script.string.lower() or "source" in script.string.lower() or "stream" in script.string.lower()):
            print(f"\nRelevant script: {script.string[:500]}")
    
    # Print the raw HTML around the player area
    player_area = soup.select_one(".anime_movie, .anime_video, .play-video, .video-js, #playercontainer")
    if player_area:
        print(f"\nPlayer area HTML ({len(str(player_area))} chars):")
        print(str(player_area)[:1000])
    else:
        print("\nNo player area found. Searching for any div with 'player' class/id...")
        for el in soup.select("[class*=player], [id*=player], [class*=video], [id*=video]"):
            print(f"  {el.name}: class={el.get('class')}, id={el.get('id')}")

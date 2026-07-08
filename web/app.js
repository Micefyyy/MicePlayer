const API = "";
let currentTab = "home";
let currentAnime = null;
let currentEpisode = null;
let hlsInstance = null;
let plyrInstance = null;
let playerEpisodes = [];
let streamDataCache = {};
let carouselInterval = null;
let carouselIndex = 0;

const getBookmarks = () => JSON.parse(localStorage.getItem("bookmarks") || "[]");
const saveBookmarks = (b) => localStorage.setItem("bookmarks", JSON.stringify(b));
const getProgress = () => JSON.parse(localStorage.getItem("progress") || "[]");
const saveProgress = (p) => localStorage.setItem("progress", JSON.stringify(p));
const getPrefs = () => JSON.parse(localStorage.getItem("prefs") || '{"quality":"1080p","autoPlay":true,"showDub":false}');
const savePrefs = (p) => localStorage.setItem("prefs", JSON.stringify(p));

function switchTab(btn) {
    document.querySelectorAll(".nav-btn").forEach(x => x.classList.remove("active"));
    btn.classList.add("active");
    const tab = btn.dataset.tab;
    showPage(tab);
}

function showPage(name) {
    document.querySelectorAll(".page").forEach(p => p.classList.remove("active"));
    document.getElementById("page-" + name).classList.add("active");
    currentTab = name;
    if (name === "home") loadHome();
    if (name === "discover") loadDiscover();
    if (name === "library") loadLibrary();
    if (name === "settings") loadSettingsPage();
}

function goHome() {
    destroyPlayer();
    currentAnime = null;
    playerEpisodes = [];
    streamDataCache = {};
    currentEpisode = null;
    showPage("home");
    document.querySelectorAll(".nav-btn").forEach(b => b.classList.toggle("active", b.dataset.tab === "home"));
}

async function api(path) {
    const r = await fetch(API + path);
    if (!r.ok) throw new Error("API error");
    return r.json();
}

function esc(s) { const d = document.createElement("div"); d.textContent = s || ""; return d.innerHTML; }

function cardHTML(a) {
    const img = a.cover_image_medium || a.cover_image_large || "";
    const score = a.score ? `<div class="score-badge">\u2605 ${(a.score/10).toFixed(1)}</div>` : "";
    const eps = a.episodes ? `${a.episodes} eps` : (a.status === "RELEASING" ? "Airing" : "");
    return `<div class="card" onclick="openDetail(${a.id})"><div class="poster"><img src="${img}" onerror="this.style.display='none'" loading="lazy"><div class="play">\u25b6</div>${score}</div><div class="details"><div class="card-title">${esc(a.title_english || a.title_romaji)}</div></div><div class="card-meta">${a.year ? a.year + " \u2022 " : ""}${eps}</div></div>`;
}

let trendingData = [], seasonalData = [], popularData = [];

async function loadHome() {
    const el = document.getElementById("page-home");
    el.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
    try {
        const [t, s, p] = await Promise.all([api("/api/trending").catch(()=>[]), api("/api/seasonal").catch(()=>[]), api("/api/popular").catch(()=>[])]);
        trendingData = t; seasonalData = s; popularData = p;
        let html = "";

        if (t.length) {
            const slides = t.slice(0, 5);
            html += `<div class="carousel" id="homeCarousel">${slides.map((a, i) => {
                const img = a.cover_image_large || a.cover_image_medium || "";
                const score = a.score ? `\u2605 ${(a.score/10).toFixed(1)}` : "";
                const eps = a.episodes ? `${a.episodes} Episodes` : "";
                const pills = [score, a.year||"", eps, a.status==="RELEASING"?"Airing":(a.status||"")].filter(Boolean).map(p => `<span class="pill">${p}</span>`).join("");
                return `<img src="${img}" class="carousel-slide" data-index="${i}" style="${i===0?'':'display:none'}">
                <div class="overlay"></div>
                <div class="info">
                    <div class="pills">${pills}</div>
                    <div class="title">${esc(a.title_english||a.title_romaji)}</div>
                    <div class="desc">${esc(a.synopsis||"").substring(0,180)}</div>
                </div>
                <div class="actions">
                    <div class="act-btn" onclick="event.stopPropagation();openDetail(${a.id})">\u25b6 Watch</div>
                    <div class="act-btn" onclick="event.stopPropagation();openDetail(${a.id})">Info</div>
                </div>`;
            }).join("")}
            <div class="counter"><span id="carouselIdx">1</span> / ${slides.length}</div>
            <div class="arrow left" onclick="event.stopPropagation();moveCarousel(-1)">&#8249;</div>
            <div class="arrow right" onclick="event.stopPropagation();moveCarousel(1)">&#8250;</div>
            </div>`;
            startCarousel(slides.length);
        }

        if (t.length) html += `<div class="section"><div class="section-header"><h2>Trending Now</h2></div><div class="card-grid">${t.map(cardHTML).join("")}</div></div>`;
        if (s.length) html += `<div class="section"><div class="section-header"><h2>Seasonal Hits</h2></div><div class="card-grid">${s.map(cardHTML).join("")}</div></div>`;
        if (p.length) html += `<div class="section"><div class="section-header"><h2>Most Popular</h2></div><div class="card-grid">${p.map(cardHTML).join("")}</div></div>`;

        el.innerHTML = html || '<div class="empty-state"><div class="title">No content available</div></div>';
    } catch(e) { el.innerHTML = '<div class="empty-state"><div class="title">Connection Error</div><div class="subtitle">Make sure the backend is running</div></div>'; }
}

function moveCarousel(dir) {
    if (!carouselInterval) return;
    const slides = document.querySelectorAll(".carousel-slide");
    if (!slides.length) return;
    carouselIndex = (carouselIndex + dir + slides.length) % slides.length;
    slides.forEach((s, i) => s.style.display = i === carouselIndex ? "" : "none");
    const counter = document.getElementById("carouselIdx");
    if (counter) counter.textContent = carouselIndex + 1;
}

function startCarousel(count) {
    if (carouselInterval) clearInterval(carouselInterval);
    carouselIndex = 0;
    carouselInterval = setInterval(() => moveCarousel(1), 5000);
}

let discoverCategory = "seasonal";
let discoverData = {};
async function loadDiscover() {
    const el = document.getElementById("page-discover");
    if (el.dataset.loaded) return;
    el.dataset.loaded = "1";
    el.innerHTML = `<div class="section" style="margin-top:0">
        <div class="section-header">
            <h2>Discover</h2>
            <div class="section-tabs">
                <button class="section-tab active" data-cat="seasonal" onclick="switchDiscoverTab(this)">Seasonal</button>
                <button class="section-tab" data-cat="trending" onclick="switchDiscoverTab(this)">Trending</button>
                <button class="section-tab" data-cat="topRated" onclick="switchDiscoverTab(this)">Top Rated</button>
            </div>
        </div>
        <div id="discoverGrid"><div class="loading"><div class="spinner"></div></div></div>
    </div>`;
    try {
        const [t, s, p] = await Promise.all([api("/api/trending").catch(()=>[]), api("/api/seasonal").catch(()=>[]), api("/api/popular").catch(()=>[])]);
        discoverData = { trending: t, seasonal: s, topRated: p };
        renderDiscoverGrid();
    } catch(e) { document.getElementById("discoverGrid").innerHTML = '<div class="empty-state"><div class="title">Failed to load</div></div>'; }
}

function switchDiscoverTab(btn) {
    document.querySelectorAll(".section-tab").forEach(p => p.classList.remove("active"));
    btn.classList.add("active");
    discoverCategory = btn.dataset.cat;
    renderDiscoverGrid();
}

function renderDiscoverGrid() {
    document.getElementById("discoverGrid").innerHTML = `<div class="card-grid">${(discoverData[discoverCategory]||[]).slice(0,24).map(cardHTML).join("")}</div>`;
}

async function doGlobalSearch() {
    const q = document.getElementById("globalSearch").value.trim();
    if (!q) return;
    showPage("discover");
    document.querySelectorAll(".nav-btn").forEach(b => b.classList.toggle("active", b.dataset.tab === "discover"));
    const el = document.getElementById("page-discover");
    el.dataset.loaded = "1";
    el.innerHTML = `<div class="section" style="margin-top:0"><div class="section-header"><h2>Search: ${esc(q)}</h2></div><div id="searchResults"><div class="loading"><div class="spinner"></div></div></div></div>`;
    try {
        const res = await api("/api/search?q=" + encodeURIComponent(q));
        document.getElementById("searchResults").innerHTML = res.length ? `<div class="card-grid">${res.map(cardHTML).join("")}</div>` : '<div class="empty-state"><div class="title">No results found</div></div>';
    } catch(e) { document.getElementById("searchResults").innerHTML = '<div class="empty-state"><div class="title">Search failed</div></div>'; }
}

function loadLibrary() {
    const el = document.getElementById("page-library");
    const progress = getProgress();
    const bookmarks = getBookmarks();
    let html = "";
    if (progress.length) {
        html += `<div class="section" style="margin-top:0"><div class="section-header"><h2>Continue Watching</h2></div><div class="card-grid">`;
        for (const p of progress.slice(0, 10)) {
            html += `<div class="card" onclick="openPlayer(${p.animeId},${p.episodeNumber},'${esc(p.animeTitle).replace(/'/g,"\\'")}','${(p.animeImage||"").replace(/'/g,"\\'")}')"><div class="poster"><img src="${p.animeImage||""}" onerror="this.style.display='none'" loading="lazy"><div class="play">\u25b6</div></div><div class="details"><div class="card-title">${esc(p.animeTitle)}</div></div><div class="card-meta accent">Ep. ${p.episodeNumber}</div></div>`;
        }
        html += "</div></div>";
    }
    if (bookmarks.length) {
        html += `<div class="section"><div class="section-header"><h2>Bookmarks</h2></div><div class="card-grid">`;
        for (const b of bookmarks) html += cardHTML(b);
        html += "</div></div>";
    }
    if (!progress.length && !bookmarks.length) html = '<div class="empty-state"><div class="title">No bookmarks yet</div><div class="subtitle">Start browsing to add anime</div></div>';
    el.innerHTML = html;
}

async function openDetail(id) {
    try {
        const [anime, episodes] = await Promise.all([api("/api/anime/" + id), api("/api/anime/" + id + "/episodes")]);
        currentAnime = anime;
        playerEpisodes = episodes;
        const progress = getProgress();
        const lastEp = progress.filter(p => p.animeId === anime.id).sort((a,b) => new Date(b.updatedAt) - new Date(a.updatedAt))[0];
        const startEp = lastEp ? lastEp.episodeNumber : 1;
        const ci = anime.cover_image_medium || anime.cover_image_large || "";
        const safeTitle = (anime.title_english || anime.title_romaji).replace(/'/g, "\\'");
        const safeImg = ci.replace(/'/g, "\\'");
        openPlayer(anime.id, startEp, safeTitle, safeImg);
    } catch(e) {
        showToast("Failed to load anime");
    }
}

function toggleBookmark(id) {
    let bookmarks = getBookmarks();
    const btn = document.getElementById("bookmarkBtn");
    if (bookmarks.some(b => b.id === id)) {
        bookmarks = bookmarks.filter(b => b.id !== id);
        if (btn) { btn.classList.remove("active"); btn.innerHTML = '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M17 3H7c-1.1 0-2 .9-2 2v16l7-3 7 3V5c0-1.1-.9-2-2-2zm0 15l-5-2.18L7 18V5h10v13z"/></svg>'; }
        showToast("Removed from bookmarks");
    } else {
        if (currentAnime) bookmarks.push(currentAnime);
        if (btn) { btn.classList.add("active"); btn.innerHTML = '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M17 3H7c-1.1 0-2 .9-2 2v16l7-3 7 3V5c0-1.1-.9-2-2-2z"/></svg>'; }
        showToast("Added to bookmarks");
    }
    saveBookmarks(bookmarks);
}

// === PLAYER ===
function destroyPlayer() {
    if (plyrInstance) { try { plyrInstance.destroy(); } catch(e) {} plyrInstance = null; }
    if (hlsInstance) { try { hlsInstance.destroy(); } catch(e) {} hlsInstance = null; }
}

function getSourceUrl(manifestUrl) {
    return API + "/proxy?url=" + encodeURIComponent(manifestUrl);
}

function resolveStream(streamData, useDub) {
    if (!streamData) return null;
    const dub = streamData.dub || [];
    const sub = streamData.sub || [];
    const sources = streamData.sources || [];
    if (useDub && dub.length) return dub[0].manifest_url;
    if (!useDub && sub.length) return sub[0].manifest_url;
    if (dub.length) return dub[0].manifest_url;
    if (sub.length) return sub[0].manifest_url;
    if (sources.length) return sources[0].manifest_url;
    return null;
}

function setupHls(video, proxyUrl, onReady) {
    if (hlsInstance) { try { hlsInstance.destroy(); } catch(e) {} hlsInstance = null; }
    if (!window.Hls || !Hls.isSupported()) {
        if (video.canPlayType("application/vnd.apple.mpegurl")) {
            video.src = proxyUrl;
            video.onloadedmetadata = onReady;
        }
        return;
    }
    hlsInstance = new Hls({ startFragPrefetch: true, maxBufferLength: 30 });
    hlsInstance.loadSource(proxyUrl);
    hlsInstance.attachMedia(video);
    hlsInstance.on(Hls.Events.MANIFEST_PARSED, (_, data) => {
        updateQualityUI(data.levels);
        onReady();
    });
    hlsInstance.on(Hls.Events.ERROR, (_, data) => {
        if (data.fatal) console.error("HLS error:", data.type, data.details);
    });
}

function updateQualityUI(levels) {
    const sel = document.getElementById("qualitySelect");
    if (!sel || !levels) return;
    sel.innerHTML = '<option value="-1">Auto</option>';
    levels.forEach((l, i) => {
        const opt = document.createElement("option");
        opt.value = i;
        opt.textContent = l.height + "p";
        sel.appendChild(opt);
    });
    sel.onchange = () => {
        if (hlsInstance) hlsInstance.currentLevel = parseInt(sel.value);
    };
}

function setQuality(height) {
    if (!hlsInstance) return;
    if (height === -1) { hlsInstance.currentLevel = -1; return; }
    const idx = hlsInstance.levels.findIndex(l => l.height === height);
    if (idx >= 0) hlsInstance.currentLevel = idx;
}

function setupPlyr(video) {
    if (plyrInstance) { try { plyrInstance.destroy(); } catch(e) {} plyrInstance = null; }
    try {
        plyrInstance = new Plyr(video, {
            display: 'block',
            controls: ['play-large','play','progress','current-time','duration','mute','volume','settings','fullscreen'],
            settings: ['speed'],
            speed: { selected: 1, options: [0.5, 0.75, 1, 1.25, 1.5, 2] },
            tooltips: { controls: true, seek: true },
            keyboard: { focused: true, global: true },
        });
    } catch(e) { console.error("Plyr error:", e); }
}

function loadStream(manifestUrl) {
    const video = document.getElementById("videoPlayer");
    const loading = document.getElementById("playerLoading");
    if (!video || !manifestUrl) return;

    destroyPlayer();

    const proxyUrl = getSourceUrl(manifestUrl);
    const onReady = () => {
        if (loading) loading.style.display = "none";
        video.play().catch(() => {});
    };

    setupHls(video, proxyUrl, onReady);
    setupPlyr(video);
}

async function openPlayer(animeId, epNum, title, image) {
    destroyPlayer();
    epGridOffset = 0;
    const el = document.getElementById("page-player");
    document.querySelectorAll(".page").forEach(p => p.classList.remove("active"));
    el.classList.add("active");
    currentEpisode = { animeId, episodeNumber: epNum };

    const prefs = getPrefs();

    if (!playerEpisodes.length || !currentAnime || currentAnime.id !== animeId) {
        el.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
        streamDataCache = {};
        try {
            const [anime, episodes] = await Promise.all([api("/api/anime/" + animeId), api("/api/anime/" + animeId + "/episodes")]);
            currentAnime = anime;
            playerEpisodes = episodes;
        } catch(e) {
            el.innerHTML = '<div class="empty-state"><div class="title">Failed to load</div></div>';
            return;
        }
    }

    const cacheKey = animeId + "_" + epNum;
    const currentEp = playerEpisodes.find(e => e.number === epNum);
    const epTitle = currentEp ? (currentEp.title || "Episode " + epNum) : "Episode " + epNum;
    const an = currentAnime;
    const ci = an.cover_image_medium || an.cover_image_large || image || "";
    const score = an.score ? `\u2605 ${(an.score/10).toFixed(1)}` : "";
    const genres = (Array.isArray(an.genres) ? an.genres : (an.genres||"").split(" ")).filter(Boolean).map(g => `<span class="genre">${g}</span>`).join("");
    const bookmarks = getBookmarks();
    const isBm = bookmarks.some(b => b.id === an.id);

    el.innerHTML = `
            <div class="player-page">
                    <div class="player-header">
                        <button class="back-btn" onclick="closePlayer()">
                            <svg viewBox="0 0 24 24" width="20" height="20" fill="white"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/></svg>
                        </button>
                        <span class="ep-title">${esc(title)} - ${esc(epTitle)}</span>
                        <div class="header-audio-toggle" id="headerAudioToggle">
                            <button class="audio-btn sub-btn ${!prefs.showDub ? 'active' : ''}">SUB</button>
                            <button class="audio-btn dub-btn ${prefs.showDub ? 'active' : ''}">DUB</button>
                        </div>
                    </div>
                <div class="player-main">
                    <div class="player-left">
                    <div class="player-loading" id="playerLoading">
                        <div class="spinner"></div>
                        <span>Loading stream...</span>
                    </div>
                    <video id="videoPlayer" playsinline></video>
                    <div class="plyr-quality-wrap"><select id="qualitySelect" class="plyr-quality-select"><option value="-1">Auto</option></select></div>
                </div>
                <div class="player-sidebar">
                    <div class="sidebar-header">
                        <span class="ep-count">${playerEpisodes.length} Episodes</span>
                    </div>
                    <div class="anime-info-card">
                        <div class="anime-info-top">
                            <img class="anime-info-cover" src="${ci}" onerror="this.style.display='none'" loading="lazy">
                            <div class="anime-info-meta">
                                <div class="anime-info-title">${esc(an.title_english||an.title_romaji)}</div>
                                <div class="anime-info-detail">
                                    ${score ? `<span>${score}</span><span class="dot"></span>` : ""}
                                    ${an.year ? `<span>${an.year}</span><span class="dot"></span>` : ""}
                                    ${an.status ? `<span>${an.status.replace(/_/g," ").toLowerCase()}</span>` : ""}
                                </div>
                                <div class="anime-info-genres">${genres}</div>
                                <div class="anime-info-actions">
                                    <button class="btn-icon-sm${isBm?" active":""}" onclick="toggleBookmark(${an.id})">
                                        <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="${isBm?"M17 3H7c-1.1 0-2 .9-2 2v16l7-3 7 3V5c0-1.1-.9-2-2-2z":"M17 3H7c-1.1 0-2 .9-2 2v16l7-3 7 3V5c0-1.1-.9-2-2-2zm0 15l-5-2.18L7 18V5h10v13z"}"/></svg>
                                    </button>
                                </div>
                            </div>
                        </div>
                        ${an.synopsis ? `<div class="anime-info-synopsis">${esc(an.synopsis).substring(0, 200)}${(an.synopsis||"").length > 200 ? "..." : ""}</div>` : ""}
                    </div>
                    ${playerEpisodes.length > 25 ? `
                    <div class="ep-pager">
                        <div class="ep-pager-controls">
                            <button class="ep-pager-btn" onclick="episodePageJump(${animeId},'${esc(title).replace(/'/g,"\\'")}','${(image||"").replace(/'/g,"\\'")}',${epNum},-100)">-100</button>
                            <button class="ep-pager-btn" onclick="episodePageJump(${animeId},'${esc(title).replace(/'/g,"\\'")}','${(image||"").replace(/'/g,"\\'")}',${epNum},-10">-10</button>
                            <span class="ep-pager-label" id="epPagerLabel"></span>
                            <button class="ep-pager-btn" onclick="episodePageJump(${animeId},'${esc(title).replace(/'/g,"\\'")}','${(image||"").replace(/'/g,"\\'")}',${epNum},10)">+10</button>
                            <button class="ep-pager-btn" onclick="episodePageJump(${animeId},'${esc(title).replace(/'/g,"\\'")}','${(image||"").replace(/'/g,"\\'")}',${epNum},100)">+100</button>
                        </div>
                        <div class="ep-grid" id="epGrid"></div>
                    </div>` : `
                    <div class="episode-list">
                        ${playerEpisodes.map(ep => `<div class="episode-row${ep.number===epNum?' current':''}" onclick="openPlayer(${animeId},${ep.number},'${esc(title).replace(/'/g,"\\'")}','${(image||"").replace(/'/g,"\\'")}')"><div class="episode-num">${ep.number}</div><div class="episode-info"><div class="ep-title">${esc(ep.title || "Episode " + ep.number)}</div></div></div>`).join("")}
                    </div>`}
                </div>
            </div>
        </div>`;

    const subBtn = document.querySelector(".header-audio-toggle .sub-btn");
    const dubBtn = document.querySelector(".header-audio-toggle .dub-btn");
    if (subBtn) { subBtn.addEventListener("click", (e) => { e.stopPropagation(); switchAudio(false); }); }
    if (dubBtn) { dubBtn.addEventListener("click", (e) => { e.stopPropagation(); switchAudio(true); }); }

    if (playerEpisodes.length > 25) {
        renderEpGrid(animeId, epNum, title, image);
    }

    try {
        if (!streamDataCache[cacheKey]) {
            streamDataCache[cacheKey] = await api("/api/anime/" + animeId + "/episode/" + epNum + "/stream");
        }
        const streamData = streamDataCache[cacheKey];
        const url = resolveStream(streamData, prefs.showDub);
        if (!url) {
            document.getElementById("playerLoading").innerHTML = '<span class="error-text">No stream available</span>';
            return;
        }
        loadStream(url);
        document.getElementById("videoPlayer").addEventListener("ended", () => {
            if (getPrefs().autoPlay && playerEpisodes.some(e => e.number === epNum + 1))
                openPlayer(animeId, epNum + 1, title, image);
        }, { once: true });
        saveProgressEntry(animeId, title, image, epNum);

        if (playerEpisodes.every(e => e.title.startsWith("Episode "))) {
            setTimeout(async () => {
                try {
                    const freshEps = await api("/api/anime/" + animeId + "/episodes");
                    if (freshEps && freshEps.length && !freshEps[0].title.startsWith("Episode ")) {
                        playerEpisodes = freshEps;
                        if (currentEpisode && currentEpisode.animeId === animeId) {
                            if (playerEpisodes.length > 25) {
                                renderEpGrid(animeId, currentEpisode.episodeNumber, title, image);
                            } else {
                                const listEl = document.querySelector(".episode-list");
                                if (listEl) {
                                    const current = currentEpisode.episodeNumber;
                                    listEl.innerHTML = playerEpisodes.map(ep => `<div class="episode-row${ep.number===current?' current':''}" onclick="openPlayer(${animeId},${ep.number},'${esc(title).replace(/'/g,"\\'")}','${(image||"").replace(/'/g,"\\'")}')"><div class="episode-num">${ep.number}</div><div class="episode-info"><div class="ep-title">${esc(ep.title || "Episode " + ep.number)}</div></div></div>`).join("");
                                }
                            }
                        }
                    }
                } catch(e) {}
            }, 500);
        }
    } catch(e) {
        console.error("Stream error:", e);
        const loading = document.getElementById("playerLoading");
        if (loading) loading.innerHTML = '<span class="error-text">Failed to load stream</span>';
    }
}

let epGridOffset = 0;
const EP_GRID_SIZE = 100;

function renderEpGrid(animeId, currentEp, title, image) {
    const grid = document.getElementById("epGrid");
    const label = document.getElementById("epPagerLabel");
    if (!grid || !playerEpisodes.length) return;
    const total = playerEpisodes.length;
    if (total <= EP_GRID_SIZE) epGridOffset = 0;
    else if (!epGridOffset && currentEp > EP_GRID_SIZE) epGridOffset = Math.floor((currentEp - 1) / EP_GRID_SIZE) * EP_GRID_SIZE;
    const start = epGridOffset;
    const end = Math.min(start + EP_GRID_SIZE, total);
    const slice = playerEpisodes.slice(start, end);
    grid.innerHTML = slice.map(ep => `<div class="ep-box${ep.number===currentEp?' current':''}" onclick="openPlayer(${animeId},${ep.number},'${(title||'').replace(/'/g,"\\'")}','${(image||'').replace(/'/g,"\\'")}')">${ep.number}</div>`).join("");
    if (label) label.textContent = `${start + 1}–${end} of ${total}`;
    const cur = grid.querySelector(".ep-box.current");
    if (cur) cur.scrollIntoView({ block: "center", behavior: "instant" });
}

function episodePageJump(animeId, title, image, currentEp, delta) {
    const total = playerEpisodes.length;
    epGridOffset = Math.max(0, Math.min(total - EP_GRID_SIZE, epGridOffset + delta));
    renderEpGrid(animeId, currentEp, title, image);
}

function switchAudio(showDub) {
    const prefs = getPrefs();
    prefs.showDub = showDub;
    savePrefs(prefs);
    document.querySelectorAll(".sub-btn").forEach(b => b.classList.toggle("active", !showDub));
    document.querySelectorAll(".dub-btn").forEach(b => b.classList.toggle("active", showDub));
    if (!currentEpisode) return;
    const cacheKey = currentEpisode.animeId + "_" + currentEpisode.episodeNumber;
    const streamData = streamDataCache[cacheKey];
    if (!streamData) return;
    const url = resolveStream(streamData, showDub);
    if (!url) return;
    const video = document.getElementById("videoPlayer");
    if (!video) return;
    if (hlsInstance) { try { hlsInstance.destroy(); } catch(e) {} hlsInstance = null; }
    const proxyUrl = getSourceUrl(url);
    if (window.Hls && Hls.isSupported()) {
        hlsInstance = new Hls({ startFragPrefetch: true, maxBufferLength: 30 });
        hlsInstance.loadSource(proxyUrl);
        hlsInstance.attachMedia(video);
        hlsInstance.on(Hls.Events.MANIFEST_PARSED, () => { video.play().catch(() => {}); });
        hlsInstance.on(Hls.Events.ERROR, (_, data) => { if (data.fatal) console.error("HLS error:", data.type, data.details); });
    } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
        video.src = proxyUrl;
        video.onloadedmetadata = () => video.play().catch(() => {});
    }
}

function closePlayer() {
    destroyPlayer();
    currentAnime = null;
    playerEpisodes = [];
    streamDataCache = {};
    currentEpisode = null;
    document.querySelectorAll(".page").forEach(p => p.classList.remove("active"));
    document.getElementById("page-" + currentTab).classList.add("active");
}

function saveProgressEntry(animeId, title, image, epNum) {
    let progress = getProgress();
    progress = progress.filter(p => !(p.animeId === animeId && p.episodeNumber === epNum));
    progress.unshift({ animeId, animeTitle: title, animeImage: image, episodeNumber: epNum, updatedAt: new Date().toISOString() });
    if (progress.length > 50) progress = progress.slice(0, 50);
    saveProgress(progress);
}

function loadSettingsPage() {
    const el = document.getElementById("page-settings");
    const prefs = getPrefs();
    el.innerHTML = `<div class="section" style="margin-top:0"><div class="section-header"><h2>Settings</h2></div>
        <div class="settings">
            <div class="settings-section"><h3>Playback</h3>
                <div class="setting-row"><label>Auto-play next episode</label><div class="toggle ${prefs.autoPlay?'on':''}" onclick="toggleSetting(this,'autoPlay')"><div class="knob"></div></div></div>
            </div>
            <div class="settings-section"><h3>About</h3>
                <div class="setting-row"><label>Version</label><span class="muted">1.0.0 (Web)</span></div>
            </div>
        </div>
    </div>`;
}
function toggleSetting(el, key) { const p = getPrefs(); p[key] = !p[key]; savePrefs(p); el.classList.toggle("on"); }
function updatePref(key, val) { const p = getPrefs(); p[key] = val; savePrefs(p); }
function showToast(msg) { const t = document.querySelector(".toast"); if (t) { t.textContent = msg; t.classList.add("show"); setTimeout(() => t.classList.remove("show"), 2000); } }

loadHome();

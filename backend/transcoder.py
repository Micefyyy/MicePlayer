"""
HLS transcoder using FFmpeg.
Slices video into .ts chunks and generates .m3u8 playlists at multiple bitrates.
"""

import subprocess
import os
import shutil
from pathlib import Path

RESOLUTIONS = [
    {"name": "360p", "size": "640x360", "bitrate": "800k", "maxrate": "856k", "bufsize": "1200k"},
    {"name": "480p", "size": "854x480", "bitrate": "1400k", "maxrate": "1498k", "bufsize": "2100k"},
    {"name": "720p", "size": "1280x720", "bitrate": "2800k", "maxrate": "2996k", "bufsize": "4200k"},
    {"name": "1080p", "size": "1920x1080", "bitrate": "5000k", "maxrate": "5350k", "bufsize": "7500k"},
]

def transcode_to_hls(input_path: str, output_dir: str, hls_time: int = 6) -> str:
    """
    Transcode a video file into HLS with multiple quality variants.
    Returns the path to the master .m3u8 playlist.
    """
    input_path = Path(input_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    variant_playlists = []

    for res in RESOLUTIONS:
        variant_dir = output_dir / res["name"]
        variant_dir.mkdir(exist_ok=True)
        playlist_path = variant_dir / "playlist.m3u8"

        cmd = [
            "ffmpeg", "-y",
            "-i", str(input_path),
            "-profile:v", "baseline",
            "-level", "3.0",
            "-s", res["size"],
            "-b:v", res["bitrate"],
            "-maxrate", res["maxrate"],
            "-bufsize", res["bufsize"],
            "-b:a", "128k",
            "-ar", "48000",
            "-start_number", "0",
            "-hls_time", str(hls_time),
            "-hls_list_size", "0",
            "-hls_segment_filename", str(variant_dir / "segment_%03d.ts"),
            "-f", "hls",
            str(playlist_path)
        ]

        subprocess.run(cmd, check=True)
        variant_playlists.append((res["name"], playlist_path))

    # Generate master playlist
    master_path = output_dir / "master.m3u8"
    with open(master_path, "w") as f:
        f.write("#EXTM3U\n")
        f.write("#EXT-X-VERSION:3\n")
        for res in RESOLUTIONS:
            relative = f"{res['name']}/playlist.m3u8"
            f.write(f"#EXT-X-STREAM-INF:BANDWIDTH={res['bitrate']},RESOLUTION={res['size']}\n")
            f.write(f"{relative}\n")

    return str(master_path)


def encrypt_hls(playlist_dir: str, key_url: str, key_file: str) -> None:
    """
    Apply AES-128 encryption to an existing HLS stream.
    Requires openssl and a key file.
    """
    from pathlib import Path
    playlist_dir = Path(playlist_dir)

    # Generate key if not exists
    if not Path(key_file).exists():
        subprocess.run([
            "openssl", "rand", "16", "-out", key_file
        ], check=True)

    # Create key info file
    key_info = playlist_dir / "key_info"
    with open(key_info, "w") as f:
        f.write(f"KEY URI:{key_url}\n")
        f.write(f"PATH:{key_file}\n")

    # Re-mux with encryption
    for res in RESOLUTIONS:
        variant_dir = playlist_dir / res["name"]
        input_playlist = variant_dir / "playlist.m3u8"
        output_playlist = variant_dir / "encrypted.m3u8"
        segment_pattern = str(variant_dir / "enc_segment_%03d.ts")

        cmd = [
            "ffmpeg", "-y",
            "-i", str(input_playlist),
            "-c", "copy",
            "-hls_key_info_file", str(key_info),
            "-hls_time", "6",
            "-hls_list_size", "0",
            "-hls_segment_filename", segment_pattern,
            "-f", "hls",
            str(output_playlist)
        ]
        subprocess.run(cmd, check=True)

    # Regenerate master playlist pointing to encrypted playlists
    master_path = playlist_dir / "master_encrypted.m3u8"
    with open(master_path, "w") as f:
        f.write("#EXTM3U\n")
        f.write("#EXT-X-VERSION:3\n")
        for res in RESOLUTIONS:
            relative = f"{res['name']}/encrypted.m3u8"
            f.write(f"#EXT-X-STREAM-INF:BANDWIDTH={res['bitrate']},RESOLUTION={res['size']}\n")
            f.write(f"{relative}\n")

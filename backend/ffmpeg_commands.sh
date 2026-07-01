#!/bin/bash
# FFmpeg HLS transcoding reference commands
# Usage: ./ffmpeg_commands.sh input.mp4 output_dir

INPUT="$1"
OUTDIR="$2"

if [ -z "$INPUT" ] || [ -z "$OUTDIR" ]; then
    echo "Usage: $0 input.mp4 output_dir"
    exit 1
fi

mkdir -p "$OUTDIR"

# --- 360p ---
ffmpeg -y -i "$INPUT" \
    -profile:v baseline -level 3.0 \
    -s 640x360 -b:v 800k -maxrate 856k -bufsize 1200k \
    -b:a 128k -ar 48000 \
    -start_number 0 -hls_time 6 -hls_list_size 0 \
    -hls_segment_filename "$OUTDIR/360p/segment_%03d.ts" \
    -f hls "$OUTDIR/360p/playlist.m3u8"

# --- 480p ---
ffmpeg -y -i "$INPUT" \
    -profile:v baseline -level 3.0 \
    -s 854x480 -b:v 1400k -maxrate 1498k -bufsize 2100k \
    -b:a 128k -ar 48000 \
    -start_number 0 -hls_time 6 -hls_list_size 0 \
    -hls_segment_filename "$OUTDIR/480p/segment_%03d.ts" \
    -f hls "$OUTDIR/480p/playlist.m3u8"

# --- 720p ---
ffmpeg -y -i "$INPUT" \
    -profile:v main -level 4.0 \
    -s 1280x720 -b:v 2800k -maxrate 2996k -bufsize 4200k \
    -b:a 128k -ar 48000 \
    -start_number 0 -hls_time 6 -hls_list_size 0 \
    -hls_segment_filename "$OUTDIR/720p/segment_%03d.ts" \
    -f hls "$OUTDIR/720p/playlist.m3u8"

# --- 1080p ---
ffmpeg -y -i "$INPUT" \
    -profile:v high -level 4.1 \
    -s 1920x1080 -b:v 5000k -maxrate 5350k -bufsize 7500k \
    -b:a 128k -ar 48000 \
    -start_number 0 -hls_time 6 -hls_list_size 0 \
    -hls_segment_filename "$OUTDIR/1080p/segment_%03d.ts" \
    -f hls "$OUTDIR/1080p/playlist.m3u8"

# --- Master Playlist ---
cat > "$OUTDIR/master.m3u8" << EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
360p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1400000,RESOLUTION=854x480
480p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720
720p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
1080p/playlist.m3u8
EOF

echo "HLS output in $OUTDIR/master.m3u8"

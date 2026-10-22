#!/usr/bin/env bash
# convert.sh — turn each given video into an MP4 (H.264 video + AAC audio) beside the original.
#
#   convert.sh file1.webm [file2.webm ...]
#
# Prints one line per input: "OK: <output path>" or "FAIL: <input> — <reason>".
# Exit status is 0 only if every file converted. Existing files are never overwritten;
# a second "clip.mp4" becomes "clip 1.mp4", then "clip 2.mp4", and so on.
#
# FFMPEG may point at a specific ffmpeg binary; by default the one beside this script is used.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FFMPEG="${FFMPEG:-$HERE/ffmpeg}"

# A downloaded app carries macOS's quarantine flag on every file inside it, and Gatekeeper
# refuses to run a quarantined command-line binary. Clear it from our own ffmpeg once.
if command -v xattr >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$FFMPEG" 2>/dev/null || true
fi

failures=0
for src in "$@"; do
  dir="$(dirname "$src")"
  base="$(basename "$src")"
  stem="${base%.*}"

  out="$dir/$stem.mp4"
  n=1
  while [ -e "$out" ]; do
    out="$dir/$stem $n.mp4"
    n=$((n + 1))
  done

  # Write to a hidden temp file first so a failed run never leaves a half-written .mp4 behind.
  tmp="$dir/.$stem.$$.part.mp4"
  if err="$("$FFMPEG" -nostdin -v error -y \
        -i "$src" \
        -map 0:v:0 -map '0:a:0?' \
        -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p \
        -vf 'pad=ceil(iw/2)*2:ceil(ih/2)*2' \
        -c:a aac -b:a 192k \
        -movflags +faststart \
        -f mp4 "$tmp" 2>&1)"; then
    mv -f "$tmp" "$out"
    echo "OK: $out"
  else
    rm -f "$tmp"
    reason="$(printf '%s\n' "$err" | tail -n 1)"
    echo "FAIL: $src — ${reason:-ffmpeg exited with an error}"
    failures=$((failures + 1))
  fi
done

[ "$failures" -eq 0 ]

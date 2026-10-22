#!/usr/bin/env bash
# Tests for src/convert.sh. Needs ffmpeg + ffprobe (set FFMPEG / FFPROBE to override PATH lookup).
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERT="$HERE/../src/convert.sh"
export FFMPEG="${FFMPEG:-ffmpeg}"
export FFPROBE="${FFPROBE:-ffprobe}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
ok()   { pass=$((pass+1)); echo "  ok   - $1"; }
bad()  { fail=$((fail+1)); echo "  FAIL - $1"; [ -n "${2:-}" ] && echo "         $2"; }

probe() { # probe <file> <stream-selector> <entry>
  "$FFPROBE" -v error -select_streams "$2" -show_entries "stream=$3" -of default=nw=1:nk=1 "$1" 2>/dev/null | head -n1
}

make_webm() { # make_webm <path> <WxH> [audio|noaudio]
  local size="$2" audio="${3:-audio}"
  if [ "$audio" = audio ]; then
    "$FFMPEG" -v error -y -f lavfi -i "testsrc=size=$size:rate=10:duration=1" -f lavfi -i "sine=frequency=440:duration=1" \
      -c:v libvpx-vp9 -b:v 200k -c:a libopus -shortest "$1"
  else
    "$FFMPEG" -v error -y -f lavfi -i "testsrc=size=$size:rate=10:duration=1" -c:v libvpx-vp9 -b:v 200k "$1"
  fi
}

echo "test: converts a webm into an mp4 beside it with H.264 video and AAC audio"
make_webm "$WORK/clip.webm" 320x240
if "$CONVERT" "$WORK/clip.webm" >"$WORK/out1.log" 2>&1 && [ -f "$WORK/clip.mp4" ]; then
  v=$(probe "$WORK/clip.mp4" v:0 codec_name); a=$(probe "$WORK/clip.mp4" a:0 codec_name)
  if [ "$v" = h264 ] && [ "$a" = aac ]; then ok "clip.mp4 is h264/aac"; else bad "codecs" "video=$v audio=$a"; fi
  grep -q "^OK: " "$WORK/out1.log" && ok "prints an OK line" || bad "prints an OK line" "$(cat "$WORK/out1.log")"
else
  bad "clip.mp4 produced" "$(cat "$WORK/out1.log")"
fi

echo "test: pads odd frame sizes to even dimensions"
make_webm "$WORK/odd.webm" 321x241
if "$CONVERT" "$WORK/odd.webm" >/dev/null 2>&1 && [ -f "$WORK/odd.mp4" ]; then
  w=$(probe "$WORK/odd.mp4" v:0 width); h=$(probe "$WORK/odd.mp4" v:0 height)
  if [ "$w" = 322 ] && [ "$h" = 242 ]; then ok "322x242"; else bad "dimensions" "${w}x${h}"; fi
else
  bad "odd.mp4 produced"
fi

echo "test: converts a webm that has no audio track"
make_webm "$WORK/silent.webm" 320x240 noaudio
if "$CONVERT" "$WORK/silent.webm" >/dev/null 2>&1 && [ -f "$WORK/silent.mp4" ]; then
  v=$(probe "$WORK/silent.mp4" v:0 codec_name)
  [ "$v" = h264 ] && ok "silent.mp4 is h264" || bad "silent codec" "$v"
else
  bad "silent.mp4 produced"
fi

echo "test: never overwrites an existing mp4"
make_webm "$WORK/dup.webm" 320x240
echo "keep me" > "$WORK/dup.mp4"
if "$CONVERT" "$WORK/dup.webm" >/dev/null 2>&1; then
  [ "$(cat "$WORK/dup.mp4")" = "keep me" ] && ok "original dup.mp4 untouched" || bad "dup.mp4 was overwritten"
  [ -f "$WORK/dup 1.mp4" ] && ok "wrote 'dup 1.mp4' instead" || bad "'dup 1.mp4' missing"
else
  bad "convert exited non-zero"
fi

echo "test: converts several files in one call"
make_webm "$WORK/a.webm" 320x240; make_webm "$WORK/b.webm" 320x240
if "$CONVERT" "$WORK/a.webm" "$WORK/b.webm" >/dev/null 2>&1 && [ -f "$WORK/a.mp4" ] && [ -f "$WORK/b.mp4" ]; then
  ok "a.mp4 and b.mp4"
else
  bad "both outputs produced"
fi

echo "test: a broken input fails loudly without stopping the others"
echo "not a video" > "$WORK/bad.webm"; make_webm "$WORK/good.webm" 320x240
"$CONVERT" "$WORK/bad.webm" "$WORK/good.webm" >"$WORK/out6.log" 2>&1; rc=$?
[ $rc -ne 0 ] && ok "exit code non-zero ($rc)" || bad "exit code was 0"
grep -q "^FAIL: " "$WORK/out6.log" && ok "prints a FAIL line" || bad "prints a FAIL line" "$(cat "$WORK/out6.log")"
[ -f "$WORK/good.mp4" ] && ok "good.mp4 still produced" || bad "good.mp4 missing"
[ ! -f "$WORK/bad.mp4" ] && ok "no half-written bad.mp4 left behind" || bad "bad.mp4 left behind"

echo
echo "$pass passed, $fail failed"
[ $fail -eq 0 ]

# WebM to MP4

A tiny Mac app. Drop `.webm` files onto it and an `.mp4` appears next to each one.
The MP4 is plain H.264 video with AAC audio, so it plays on every Mac, iPhone, iPad,
Windows PC, Android phone, TV and web browser without any extra software.

Nothing else to install: ffmpeg is bundled inside the app. Works on Apple Silicon and Intel Macs, macOS 11 or newer.

## Install

### Easiest: paste one line into Terminal

Open **Terminal** (press `⌘ Space`, type `Terminal`, press Return), paste this, press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/jarediac/webm-to-mp4/main/install.sh | bash
```

That downloads the app into your Applications folder. No security warnings, because files
downloaded this way are not flagged by macOS.

### Or: download the installer

1. Download **[WebM-to-MP4.pkg](https://github.com/jarediac/webm-to-mp4/releases/latest/download/WebM-to-MP4.pkg)**.
2. Double-click it. macOS will say it *"cannot be opened because it is from an unidentified developer"*.
   That is because this app is not registered with Apple's paid developer program, not because anything is wrong with it.
   - **macOS 15 Sequoia or newer:** open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the message about WebM-to-MP4.pkg.
   - **macOS 14 or older:** right-click (or Control-click) the `.pkg` and choose **Open**, then **Open** again.
3. Click **Continue**, then **Install**. The app lands in your Applications folder.

There is also a [WebM-to-MP4.dmg](https://github.com/jarediac/webm-to-mp4/releases/latest/download/WebM-to-MP4.dmg)
if you prefer dragging the app to Applications yourself; it needs the same right-click → Open on first launch.

## Use

- **Drag and drop:** drop one or more `.webm` files onto the **WebM to MP4** icon (in Applications, or keep it in the Dock).
- **Or double-click** the app and pick the files.

Each file gets converted and the MP4 is saved in the same folder with the same name.
Existing files are never overwritten: if `clip.mp4` already exists you get `clip 1.mp4`.
A dialog tells you when it is finished. Long videos take a while; a minute of 1080p video takes roughly 10 to 30 seconds.

It also happily converts other formats ffmpeg can read (`.mkv`, `.mov`, `.avi`, and so on).

## What it produces

| | |
|---|---|
| Container | MP4, with the index at the front so it streams and previews instantly |
| Video | H.264 (`libx264`), CRF 20, `yuv420p` pixel format for QuickTime and iOS compatibility |
| Audio | AAC, 192 kbps (dropped cleanly if the source has no audio) |
| Sizing | Odd widths or heights are padded by one pixel; H.264 needs even dimensions |

## Building it yourself

The app is an AppleScript droplet (`src/droplet.applescript`) that calls `src/convert.sh`,
which runs a static universal `ffmpeg` bundled into the app. The build needs a Mac:

```bash
build/build.sh 1.0.0
```

That writes `dist/WebM to MP4.app`, `WebM-to-MP4.pkg`, `WebM-to-MP4.dmg` and `WebM-to-MP4.app.zip`.
GitHub Actions does the same on every push and attaches the files to a release when a `v*` tag is pushed:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

### Tests

`tests/test_convert.sh` checks the conversion script with real ffmpeg (any platform):

```bash
bash tests/test_convert.sh
```

Set `FFMPEG` and `FFPROBE` to point at specific binaries if they are not on your PATH.

## License

The scripts are MIT. The bundled ffmpeg is from [ffmpeg-static](https://github.com/eugeneware/ffmpeg-static)
and is GPL-licensed; its license ships inside the app as `ffmpeg-LICENSE.txt`.

# RTScan

Point your iPhone's camera at a Netflix (or any streaming) screen, and RTScan
reads on-screen titles via OCR, looks up the Rotten Tomatoes score via OMDb,
and shows a color-coded popup. Tap the popup to open the title's Rotten
Tomatoes page.

## How it works

- `CameraManager` runs a live `AVCaptureSession` and samples frames at most
  once every ~1.2s (throttled, to keep things smooth and avoid hammering the
  API).
- `TextDetector` runs Apple's Vision `VNRecognizeTextRequest` (OCR) on each
  sampled frame and filters out short/noisy UI chrome (e.g. "Episodes",
  "Play").
- `OMDbService` takes the best candidate string, searches OMDb for a matching
  title, then fetches its Rotten Tomatoes percentage from the full record.
  Results are cached in-memory so repeat detections of the same title don't
  re-hit the network.
- `ScorePopupView` renders a floating card colored by score tier
  (Certified Fresh / Fresh / Mixed / Rotten) that links out to Rotten
  Tomatoes when tapped.

This is a **text-recognition-based** approach (reading the title text Netflix
already displays), not an image-classification approach — there's no public
poster/thumbnail image database to match against, so OCR on the title text is
the practical way to identify what's on screen without training a custom
model per title.

## Setup — no Mac required (Windows/PC workflow)

There's no way to compile or sign an iOS app without Xcode somewhere, and
Xcode only runs on macOS — but you don't need to own a Mac. This project
builds the app on a **free macOS runner in GitHub Actions**, and you sideload
the resulting `.ipa` onto your iPhone from your PC using **Sideloadly**.

You will need: a free GitHub account, a free Apple ID, and a USB cable for
your iPhone.

### 1. Get an OMDb API key

https://www.omdbapi.com/apikey.aspx — free tier, 1,000 requests/day, key
arrives by email instantly. Open [Config.swift](RTScan/RTScan/Config.swift)
and replace `YOUR_OMDB_API_KEY` with it.

### 2. Push this project to a GitHub repo

```
git init
git add .
git commit -m "RTScan initial commit"
git branch -M main
git remote add origin https://github.com/<your-username>/RTScan.git
git push -u origin main
```

(Create the empty repo on github.com first, or use `gh repo create` if you
have the GitHub CLI.)

### 3. Let GitHub Actions build the IPA

Pushing to `main` automatically triggers
[`.github/workflows/build.yml`](.github/workflows/build.yml), which spins up
a temporary macOS machine, uses **XcodeGen** to turn
[`project.yml`](project.yml) into a real `.xcodeproj` (so you never have to
hand-build a Mac-only project file), and runs `xcodebuild` to produce an
**unsigned** `RTScan.ipa`. You can also trigger it manually from the repo's
**Actions** tab ("Run workflow").

When the run finishes (a few minutes), open it in the **Actions** tab and
download the `RTScan-ipa` artifact — it's a zip containing `RTScan.ipa`.

### 4. Sideload the IPA from your PC

1. Install [Sideloadly](https://sideloadly.io/) (Windows) and Apple's
   [iTunes](https://www.apple.com/itunes/download/) or just the
   "Apple Mobile Device Support" drivers, so Windows can see your iPhone over
   USB.
2. Plug in your iPhone, unlock it, tap "Trust This Computer" if prompted.
3. Open Sideloadly, drag `RTScan.ipa` into it, enter your Apple ID in the
   field provided (this is only used locally to request a free signing
   certificate from Apple — Sideloadly doesn't need your password sent
   anywhere but Apple's own servers), and click **Start**.
4. On the iPhone: **Settings > General > VPN & Device Management**, tap your
   Apple ID under "Developer App", and tap **Trust**.
5. Launch RTScan from the home screen, grant camera access, and point the
   phone at a Netflix screen.

### Re-signing reminder

A **free** Apple ID's app signature expires after **7 days** — after that,
re-run Sideloadly (no need to rebuild, the same `.ipa` works) to reinstall.
If this gets old, a **paid Apple Developer account** ($99/year) extends that
to 1 year and removes the 3-app-at-once limit free accounts have.

### Iterating on the code

Without a Mac you can't attach a live debugger or view `print()`/console
logs from the device. The practical loop is: edit the `.swift` files in this
repo → commit & push → GitHub Actions rebuilds the `.ipa` → re-sideload. If
you want faster iteration with real debugging, the cheapest path is renting
a cloud Mac by the hour (e.g. MacinCloud) purely to run Xcode's debugger
against the same code.

## Known limitations / things to tune

- **OCR accuracy depends on text size/contrast.** Netflix's browse grid often
  shows titles in small text under thumbnails — holding the phone closer or
  scanning the show's detail page (large title at top) works more reliably
  than the small grid view.
- **OMDb's free tier is movies/TV from IMDb's database** — very obscure or
  Netflix-original-only titles may not resolve.
- **The Rotten Tomatoes link is a search-results link**, not a guaranteed
  direct deep link, since OMDb doesn't return RT's internal URL slug. Tapping
  the popup takes the user to RT's search page pre-filled with the title,
  which reliably lands on the right page in one more tap.
- Tune `scanInterval` in `CameraManager.swift` (default 1.2s) if scanning
  feels too slow/fast, and the `60/40/75` thresholds in `ScoreModels.swift`
  if you want different color tier cutoffs.

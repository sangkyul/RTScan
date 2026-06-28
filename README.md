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
builds **and signs and uploads** the app on a free macOS runner in GitHub
Actions; you install it from there. Two paths, pick one:

- **TestFlight (recommended if you have a paid Apple Developer account)** —
  CI signs the build with your real distribution certificate and uploads it
  straight to TestFlight. You install/update via the TestFlight app on your
  phone. No cable, no resigning every 7 days. See "TestFlight setup" below.
- **Sideloadly (works with just a free Apple ID)** — see the original
  unsigned-IPA + Sideloadly steps further down. Simpler to set up, but
  builds expire after 7 days and need re-sideloading over USB.

---

## TestFlight setup (paid Apple Developer account)

This uses [fastlane](https://fastlane.tools) running inside GitHub Actions
to: generate a distribution certificate + provisioning profile (via
`match`), build the app, and upload it to TestFlight — all non-interactively,
all on GitHub's macOS runner. You do the one-time setup below from a browser
on your PC; no Xcode involved.

### 1. Register the bundle ID and create the app record

1. In the [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list),
   register an App ID matching `com.sangkyul.rtscan` (or change
   `PRODUCT_BUNDLE_IDENTIFIER` in [project.yml](project.yml) and
   `APP_IDENTIFIER` in [.github/workflows/build.yml](.github/workflows/build.yml)
   / [fastlane/Appfile](fastlane/Appfile) / [fastlane/Matchfile](fastlane/Matchfile)
   to whatever you choose — keep them all consistent).
2. In [App Store Connect](https://appstoreconnect.apple.com/) → **My Apps**
   → **+** → **New App**, create an iOS app with that same bundle ID.

### 2. Create an App Store Connect API key

App Store Connect → **Users and Access** → **Integrations** → **App Store
Connect API** → generate a key with the **App Manager** role. Note the
**Key ID** and **Issuer ID**, and download the `.p8` file — Apple only lets
you download it once, keep it safe.

### 3. Create a private repo for certificates (fastlane `match`)

`match` needs somewhere to store the generated certificate/profile,
encrypted. Create a second, **private** GitHub repo (e.g.
`rtscan-certificates`) for this — it just holds encrypted files, never your
app code.

### 4. Add GitHub Actions secrets

In the **RTScan** repo → **Settings** → **Secrets and variables** →
**Actions**, add:

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | Your 10-character Team ID (Apple Developer portal → Membership) |
| `ASC_KEY_ID` | The Key ID from step 2 |
| `ASC_ISSUER_ID` | The Issuer ID from step 2 |
| `ASC_KEY_CONTENT` | The `.p8` file content, base64-encoded (e.g. `certutil -encode key.p8 tmp.b64` on Windows, then strip the header/footer lines, or `base64 -w0 key.p8` on Linux/macOS/WSL) |
| `MATCH_PASSWORD` | Any passphrase you choose — encrypts the certs repo |
| `MATCH_GIT_URL` | `https://github.com/<you>/rtscan-certificates.git` |
| `MATCH_GIT_BASIC_AUTHORIZATION` | A [GitHub PAT](https://github.com/settings/tokens) (classic, `repo` scope) base64-encoded as `username:token`, so CI can push/pull the certs repo |

### 5. Push

Pushing to `main` now triggers
[`.github/workflows/build.yml`](.github/workflows/build.yml), which installs
XcodeGen + fastlane, generates the Xcode project, and runs the `beta` lane
([fastlane/Fastfile](fastlane/Fastfile)): `match` fetches/creates your
signing certificate and provisioning profile, `build_app` produces a signed
`.ipa`, and `upload_to_testflight` ships it.

### 6. Install via TestFlight

1. Install the **TestFlight** app from the App Store on your iPhone.
2. In App Store Connect → your app → **TestFlight** tab → **Internal
   Testing**, add yourself (the Apple ID on your developer account) as a
   tester if you aren't already. Internal testing builds are available
   within minutes, no App Review wait.
3. Accept the TestFlight invite email, open the TestFlight app, install
   RTScan, grant camera access, and test it.
4. Every future push to `main` uploads a new build automatically — open
   TestFlight to update.

---

## Alternative: Sideloadly (free Apple ID, no developer account needed)

Skip this section if you're using TestFlight above — it's kept here for
reference if you ever want to go back to a no-developer-account setup. Note
that [.github/workflows/build.yml](.github/workflows/build.yml) in this repo
is currently wired for the TestFlight/fastlane path; to use Sideloadly
instead you'd revert it to a plain `xcodebuild archive` step with
`CODE_SIGNING_ALLOWED=NO` (and the matching settings in
[project.yml](project.yml)) instead of running `fastlane beta`.

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

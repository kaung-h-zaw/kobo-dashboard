# Kobo Apple Dashboard

## 1. What this project does

This project turns a Kobo Nia running the native `usetrmnl/trmnl-kobo` client into a landscape Apple Calendar, Reminders, and live-weather dashboard. A small Swift app on the Mac reads iCloud-synced data through Apple's public EventKit framework and uploads JSON to one Node.js Web Service on Render. The server adds cached current weather and maintains a signed, monochrome PNG for the Kobo client.

The dashboard UI uses the official **TRMNL Framework 3.2.0** rather than project-specific imitation CSS. Its CSS, JavaScript runtime, and TRMNL font files are committed under `public/`, so a deployed screen never depends on a CDN. Headless Chromium renders that real framework page to a PNG; this is the same general rendering approach used by TRMNL's official Node BYOS example.

The landscape composition is inspired by the dense plugin mashups shown in the official `trmnl-kobo` repository: a wide agenda occupies the left side, with a large current-weather module and Apple Reminders on the right. The Kobo client itself does not contain that layout; this server creates it using Framework Grid, Flex, Item, typography, divider, clamp, overflow, and title-bar primitives.

There is no Docker, database, Redis, background worker, Apple password, private Apple API, or iCloud scraping.

Routes:

- `GET /` — public sample-data browser preview
- `GET /dashboard` — public sample-data landscape dashboard
- `GET /preview/trmnl` — framed, full-size TRMNL Framework browser preview
- `GET /api/dashboard` — public sample dashboard JSON; never contains Apple data
- `GET /health` — public health check
- `POST /api/apple-sync` — authenticated Apple data upload
- `GET /api/apple-data` — authenticated raw-data debugging endpoint
- `GET /api/display` — authenticated TRMNL metadata endpoint
- `GET /screens/dashboard.png?...` — short-lived signed Kobo image URL

Official implementation references:

- [TRMNL Framework releases](https://trmnl.com/framework/releases) — pinned release 3.2.0
- [TRMNL Framework documentation](https://trmnl.com/framework/docs/3.1)
- [Official `usetrmnl/trmnl-framework` repository](https://github.com/usetrmnl/trmnl-framework)
- [Official Node BYOS image server](https://github.com/usetrmnl/byos_node_lite)

## 2. Architecture

```text
iPhone / iPad
      |
    iCloud
      |
Apple Calendar + Reminders
      |
Mac EventKit helper (every 5 minutes)
      |  Authorization: Bearer APPLE_SYNC_SECRET
      v
POST /api/apple-sync on one Render Web Service
      |
data/apple-data.json (temporary Render filesystem)
      |
TRMNL Framework HTML at a logical 1024 x 758
      |
Headless Chromium + monochrome conversion + 90° rotation
      |
physical 758 x 1024 PNG
      |
GET /api/display -> signed URL for an already-valid cached PNG
      |
Native usetrmnl/trmnl-kobo client -> FBInk -> Kobo Nia
```

## 3. Render setup

The existing service remains a single Node Web Service:

- **Build Command:** `npm install`
- **Start Command:** `npm start`
- **Health Check Path:** `/health`
- **Instance Type:** Free

Pushes to the connected GitHub branch trigger the normal Render deployment. The server continues to listen on Render's `PORT` at `0.0.0.0`.

The data file is intentionally simple. Render's filesystem is ephemeral, so `data/apple-data.json` can disappear after a restart, redeployment, or free-instance spin-down. The Mac LaunchAgent resends the full snapshot every five minutes, which restores it automatically.

Render does not retain Puppeteer's downloaded Chrome binary between its build and runtime environments. When Express starts, it prepares Chrome inside `/tmp/kobo-dashboard-chrome` and renders a replacement screen asynchronously. The Kobo image route never waits for Chrome: it immediately serves the committed fallback or the latest successful render. No second service or worker is involved. Local development continues to use `render-chrome/`. Node.js 20 or newer is required.

## 4. Render environment variables

In the Render service, open **Environment** and configure:

| Variable | Value |
| --- | --- |
| `DEVICE_API_KEY` | Existing KOReader device key |
| `ALLOWED_DEVICE_ID` | Existing Kobo MAC, such as `58:B0:D4:AF:59:D3` |
| `BASE_URL` | `https://kobo-dashboard-7ub6.onrender.com` |
| `TIMEZONE` | `Asia/Bangkok` |
| `APPLE_SYNC_SECRET` | A new random secret used only by the Mac helper |
| `KOBO_ROTATE_IMAGE` | `true` |
| `WEATHER_LOCATION` | `Bangkok` |
| `WEATHER_LATITUDE` | `13.7563` |
| `WEATHER_LONGITUDE` | `100.5018` |

Weather comes from Open-Meteo's current-conditions API and does not need an API key. The server caches it in memory for 15 minutes. If the request times out or Open-Meteo is unavailable, the last successful conditions remain visible; before the first successful request, the dashboard uses the existing Bangkok placeholder.

Generate the new Apple sync secret on the Mac:

```bash
openssl rand -hex 32
```

Copy the result directly into Render and the LaunchAgent file. Never put its real value in GitHub. The tracked [.env.example](.env.example) contains names only.

## 5. Apple sync helper setup

The helper requires macOS 13 or newer and the Apple command-line developer tools. Open Terminal and run:

```bash
cd /Users/kaunghtetzaw/kobo-dashboard/mac-sync
./scripts/build-app.sh
```

The signed local app bundle will be:

```text
/Users/kaunghtetzaw/kobo-dashboard/mac-sync/.build/KoboAppleSync.app
```

The script builds the Swift release executable, creates a standard macOS `.app` bundle, copies its privacy-aware `Info.plist`, enables Hardened Runtime, adds the Calendar/EventKit entitlement, and ad-hoc signs the finished app for local use. Rebuild whenever the Swift source, package, plist, entitlement, or build script changes.

The helper reads:

- incomplete reminders, sorted overdue → today → upcoming → undated;
- reminder title, notes, due date/time, priority, list, and identifier;
- Calendar events from today through the following seven days;
- event title, start/end, calendar, all-day status, location, notes, and identifier.

EventKit only returns calendars available for the requested entity type. Apple's public `EKCalendar` API does not expose Calendar.app's hidden/visible checkbox, so the helper cannot inspect that UI-only state without using a forbidden private API.

## 6. EventKit permissions

Request permissions before reading or uploading anything:

```bash
cd /Users/kaunghtetzaw/kobo-dashboard/mac-sync
./scripts/request-permissions.sh
```

Do not execute `KoboAppleSync.app/Contents/MacOS/KoboAppleSync` directly from a VS Code or other IDE terminal. macOS attributes a directly executed child process's privacy request to the IDE, which does not contain this app's EventKit entitlement or purpose strings. The script launches the bundle through macOS LaunchServices and prints the app's captured output afterward.

The terminal prints the current status before requesting access. A first run should progress like this:

```text
Apple Calendar authorization status: notDetermined
Apple Calendar authorization status: fullAccess
Apple Reminders authorization status: notDetermined
Apple Reminders authorization status: fullAccess
EventKit permission check complete.
```

On macOS 13, the granted status is printed as `authorized`; on macOS 14 and later it is `fullAccess`. Other exact values include `denied`, `restricted`, and `writeOnly`. The helper requests only when the status is `notDetermined`, and it uses full access because it reads data.

Approve both macOS prompts:

- “Kobo Apple Sync” would like to access your calendars
- “Kobo Apple Sync” would like to access your reminders

The prompt text comes from the app bundle:

```text
Kobo Dashboard needs access to Calendar to display upcoming events on my Kobo.
Kobo Dashboard needs access to Reminders to display tasks on my Kobo.
```

After approval, **Kobo Apple Sync** appears under **System Settings → Privacy & Security → Calendars** and **Reminders**. The entry belongs to the app bundle, not Terminal.

If either status is already `denied`, macOS will not show that prompt again. Reset only this app's decisions, then rerun the permissions command:

```bash
tccutil reset Calendar com.kaung.KoboAppleSync
tccutil reset Reminders com.kaung.KoboAppleSync
cd /Users/kaunghtetzaw/kobo-dashboard/mac-sync
./scripts/request-permissions.sh
```

If a per-app reset says the bundle identifier is unknown, register the built bundle once and retry:

```bash
open -R /Users/kaunghtetzaw/kobo-dashboard/mac-sync/.build/KoboAppleSync.app
```

As a broader development-only fallback, `tccutil reset Calendar` and `tccutil reset Reminders` reset those permissions for every app in the current user account. The helper never requests an Apple ID or password.

## 7. Manual Apple sync test

### Verify JSON without uploading

```bash
cd /Users/kaunghtetzaw/kobo-dashboard/mac-sync
TIMEZONE=Asia/Bangkok ./scripts/run-sync.sh --dry-run
```

The printed JSON should contain `syncedAt`, `reminders`, and `events`.

### Upload to Render

Replace the placeholder with the same secret stored in Render:

```bash
cd /Users/kaunghtetzaw/kobo-dashboard/mac-sync
APPLE_SYNC_SECRET='REPLACE_WITH_YOUR_SECRET' \
KOBO_SERVER_URL='https://kobo-dashboard-7ub6.onrender.com' \
TIMEZONE='Asia/Bangkok' \
./scripts/run-sync.sh
```

A successful upload ends with:

```text
Sync successful
```

Verify the protected server copy with either the Apple secret:

```bash
curl 'https://kobo-dashboard-7ub6.onrender.com/api/apple-data' \
  -H 'Authorization: Bearer REPLACE_WITH_YOUR_SECRET'
```

or the existing device key:

```bash
curl 'https://kobo-dashboard-7ub6.onrender.com/api/apple-data' \
  -H 'access-token: REPLACE_WITH_DEVICE_API_KEY'
```

## 8. Automatic five-minute sync

The example [LaunchAgent](mac-sync/com.kaung.kobo-apple-sync.plist) already contains this project's executable and log paths. Copy it first, then edit only the private copy so a real secret never enters the git working tree:

```bash
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cp /Users/kaunghtetzaw/kobo-dashboard/mac-sync/com.kaung.kobo-apple-sync.plist \
  "$HOME/Library/LaunchAgents/"
nano "$HOME/Library/LaunchAgents/com.kaung.kobo-apple-sync.plist"
```

Replace `REPLACE_WITH_YOUR_SECRET`, save with `Control-O`, press Return, then exit with `Control-X`.

Install and secure it:

```bash
chmod 600 "$HOME/Library/LaunchAgents/com.kaung.kobo-apple-sync.plist"
plutil -lint "$HOME/Library/LaunchAgents/com.kaung.kobo-apple-sync.plist"
```

Load it and trigger an immediate run:

```bash
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.kaung.kobo-apple-sync.plist"
launchctl kickstart -k "gui/$(id -u)/com.kaung.kobo-apple-sync"
```

Check status and logs:

```bash
launchctl print "gui/$(id -u)/com.kaung.kobo-apple-sync"
tail -f "$HOME/Library/Logs/kobo-apple-sync.log"
tail -f "$HOME/Library/Logs/kobo-apple-sync-error.log"
```

Unload it before editing or replacing it:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.kaung.kobo-apple-sync.plist"
```

After editing, run the `bootstrap` and `kickstart` commands again. A LaunchAgent runs only while this user is logged in, and a sleeping or powered-off Mac cannot sync.

## 9. Native trmnl-kobo configuration

Install the current release from the official [`usetrmnl/trmnl-kobo`](https://github.com/usetrmnl/trmnl-kobo) repository, including its documented NickelMenu and KoboStuff prerequisites. Copy its `TRMNL` directory to `.adds/TRMNL/` and its NickelMenu entry to `.adds/nm/TRMNL.ini`.

Configure `.adds/TRMNL/config.json`:

```json
{
  "TrmnlId": "58:B0:D4:AF:59:D3",
  "TrmnlToken": "REPLACE_WITH_DEVICE_API_KEY",
  "TrmnlApiUrl": "https://kobo-dashboard-7ub6.onrender.com/api",
  "DebugToScreen": 0,
  "LoopMaxIteration": 0,
  "ConnectedGracePeriod": 5,
  "ImageFormat": "png",
  "IgnoreCurlErrors": "true",
  "WpaNetworkId": "-1"
}
```

`TrmnlApiUrl` must end in `/api`; the native script appends `/display`. Selecting **TRMNL** in NickelMenu stops Nickel and starts its fetch/display/sleep loop. `LoopMaxIteration: 0` keeps that loop running indefinitely.

`GET /api/display` accepts either the matching `Access-Token` or allowed `ID`. It returns `image_url`, `filename`, and a refresh interval. While only the fallback screen is ready, the interval is 60 seconds. After the first live render, it becomes 1800 seconds. The image URL is signed because the native client's second curl request does not forward device headers.

## 10. TRMNL Framework screen and landscape mode

The logical browser canvas is exactly **1024 × 758**. Preview it locally with:

```bash
npm install
npm start
```

Then open <http://localhost:3000/preview/trmnl>. `/dashboard` uses the same unframed screen, while `/` remains a convenient framed sample-data preview.

The committed official release assets are:

```text
public/trmnl/plugins.min.css
public/trmnl/plugins.min.js
public/trmnl/RELEASE_NOTES.md
public/trmnl/framework_colors.resolved.json
public/fonts/Inter*.ttf
public/fonts/TRMNL12-*
public/fonts/TRMNL16-*
public/fonts/TRMNL21-*
```

The screen uses the documented `screen > view view--full > layout + title_bar` hierarchy. Its content uses Framework Grid, Flex, Item, Title, Value, Label, Description, Divider, spacing/gap, `data-clamp`, and `data-overflow` primitives. Custom CSS is limited to the Kobo Nia's 1024 × 758 logical dimensions and browser-preview positioning/background.

For the native Kobo client, keep:

```text
KOBO_ROTATE_IMAGE=true
```

The server renders the logical landscape page and rotates the finished bitmap 90 degrees, producing the required **758 × 1024** physical PNG. If a different client already rotates downloaded images, set this variable to `false` to serve the unrotated 1024 × 758 bitmap.

To deploy, commit and push these files to the GitHub branch connected to Render. Keep the existing single Web Service, `npm install` Build Command, and `npm start` Start Command. No second service or Docker image is needed.

## 11. Troubleshooting

### TRMNL returns HTTP 401

- Confirm `TrmnlToken` matches `DEVICE_API_KEY`, or `TrmnlId` matches `ALLOWED_DEVICE_ID`.
- Set `TrmnlApiUrl` to the server URL ending in `/api`, not `/api/display`.

### Apple upload returns HTTP 401

- Confirm the helper and Render use the same `APPLE_SYNC_SECRET`.
- The header must be `Authorization: Bearer <secret>`.

### Apple upload returns HTTP 400

- Run `--dry-run` and inspect the JSON.
- Check `kobo-apple-sync-error.log` for the validation message.

### Permission denied

- Check **System Settings → Privacy & Security → Calendars** and **Reminders**.
- Run the compiled release executable manually again.

### Render unavailable

- Test <https://kobo-dashboard-7ub6.onrender.com/health>.
- A free Render service can need time to wake after inactivity. The helper reports non-2xx status codes and tries again at the next five-minute LaunchAgent run.

### Native Kobo client shows logs over the old Kobo home screen

Set `DebugToScreen` to `0` after troubleshooting. The signed image route always returns a valid PNG, even while Chrome is installing or if a later render fails. Render logs report `Dashboard screen refresh failed:` without replacing the last good screen.

### No Apple data after a restart

Render's local filesystem is ephemeral. Wait for the next Mac sync or run the helper manually.

### Check server data without exposing it publicly

Use authenticated `/api/apple-data` as shown in the manual test section. An unauthenticated request returns HTTP 401.

## 12. Security

- Apple credentials never leave Apple devices and are never stored by this project.
- The Mac uses only Apple's public EventKit framework.
- `APPLE_SYNC_SECRET` protects uploads; `DEVICE_API_KEY` or `APPLE_SYNC_SECRET` protects raw-data debugging.
- Device metadata supports the existing `access-token` or allowed `ID` authentication.
- Screen downloads use short-lived HMAC signatures.
- Public preview routes contain sample data only.
- JSON bodies are limited to 256 KB and validated before storage.
- Text is XML-escaped before SVG/PNG rendering.
- Secrets are compared with timing-safe logic and are never logged.
- `.env`, Apple data, Swift build products, and local secrets are ignored by git.

Official Apple references used for the helper: [Accessing the event store](https://developer.apple.com/documentation/eventkit/accessing-the-event-store), [Retrieving events and reminders](https://developer.apple.com/documentation/eventkit/retrieving-events-and-reminders), and [`EKCalendar`](https://developer.apple.com/documentation/eventkit/ekcalendar).

## 13. Local interactive KOReader plugin (Version 1)

A new, independent local dashboard is available under [`kobo-plugin/`](kobo-plugin/README.md). It runs as a custom KOReader plugin, uses five separate fullscreen pages with horizontal swipe navigation, and includes touch interactions for mock reminders and a stacked Kanban board.

This Version 1 plugin makes no network requests and does not alter or replace the Render server, macOS sync helper, or TRMNL client described above. See the plugin README for exact copy/install, configuration, testing, and uninstall instructions.

## 14. Standalone NickelMenu dashboard

The newer standalone direction is under [`kobo-app/`](kobo-app/README.md). It launches directly from NickelMenu, uses bundled LuaJIT and FBInk executables, reads Kobo Nia touch events without KOReader, and returns to Nickel on exit. Version 1 remains fully local and offline.

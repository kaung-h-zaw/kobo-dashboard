# Kobo Apple Dashboard

## 1. What this project does

This project turns a Kobo Nia running KOReader into a landscape Apple Calendar and Reminders dashboard. A small Swift program on the Mac reads iCloud-synced data through Apple's public EventKit framework and uploads JSON to one Node.js Web Service on Render. The server creates a signed, monochrome PNG for the official TRMNL KOReader plugin.

There is no Docker, database, Redis, browser automation, background worker, Apple password, private Apple API, or iCloud scraping.

Routes:

- `GET /` — public sample-data browser preview
- `GET /dashboard` — public sample-data landscape dashboard
- `GET /api/dashboard` — public sample dashboard JSON; never contains Apple data
- `GET /health` — public health check
- `POST /api/apple-sync` — authenticated Apple data upload
- `GET /api/apple-data` — authenticated raw-data debugging endpoint
- `GET /api/display` — authenticated TRMNL metadata endpoint
- `GET /screens/dashboard.png?...` — short-lived signed Kobo image URL

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
1024 x 758 monochrome PNG
      |
GET /api/display -> signed image_url
      |
Official TRMNL KOReader plugin -> Kobo Nia
```

## 3. Render setup

The existing service remains a single Node Web Service:

- **Build Command:** `npm install`
- **Start Command:** `npm start`
- **Health Check Path:** `/health`
- **Instance Type:** Free

Pushes to the connected GitHub branch trigger the normal Render deployment. The server continues to listen on Render's `PORT` at `0.0.0.0`.

The data file is intentionally simple. Render's filesystem is ephemeral, so `data/apple-data.json` can disappear after a restart, redeployment, or free-instance spin-down. The Mac LaunchAgent resends the full snapshot every five minutes, which restores it automatically.

## 4. Render environment variables

In the Render service, open **Environment** and configure:

| Variable | Value |
| --- | --- |
| `DEVICE_API_KEY` | Existing KOReader device key |
| `ALLOWED_DEVICE_ID` | Existing Kobo MAC, such as `58:B0:D4:AF:59:D3` |
| `BASE_URL` | `https://kobo-dashboard-7ub6.onrender.com` |
| `TIMEZONE` | `Asia/Bangkok` |
| `APPLE_SYNC_SECRET` | A new random secret used only by the Mac helper |
| `KOBO_ROTATE_IMAGE` | `false` initially |

Generate the new Apple sync secret on the Mac:

```bash
openssl rand -hex 32
```

Copy the result directly into Render and the LaunchAgent file. Never put its real value in GitHub. The tracked [.env.example](.env.example) contains names only.

## 5. Apple sync helper setup

The helper requires macOS 13 or newer and the Apple command-line developer tools. Open Terminal and run:

```bash
cd /Users/kaunghtetzaw/kobo-dashboard/mac-sync
swift build -c release
```

The executable will be:

```text
/Users/kaunghtetzaw/kobo-dashboard/mac-sync/.build/release/KoboAppleSync
```

Rebuild the helper whenever `main.swift`, `Package.swift`, or its permission descriptions change. Run the final release binary manually once before installing the LaunchAgent so macOS can show its permission prompts.

The helper reads:

- incomplete reminders, sorted overdue → today → upcoming → undated;
- reminder title, notes, due date/time, priority, list, and identifier;
- Calendar events from today through the following seven days;
- event title, start/end, calendar, all-day status, location, notes, and identifier.

EventKit only returns calendars available for the requested entity type. Apple's public `EKCalendar` API does not expose Calendar.app's hidden/visible checkbox, so the helper cannot inspect that UI-only state without using a forbidden private API.

## 6. EventKit permissions

First run a dry sync. It reads and prints data but uploads nothing:

```bash
cd /Users/kaunghtetzaw/kobo-dashboard/mac-sync
TIMEZONE=Asia/Bangkok .build/release/KoboAppleSync --dry-run
```

Approve both prompts:

- Apple Reminders access
- Apple Calendar access

Expected terminal messages include:

```text
Apple Reminders permission: OK
Apple Calendar permission: OK
Found 8 incomplete reminders
Found 5 upcoming events
```

If access was denied, open **System Settings → Privacy & Security → Calendars** and **Reminders**, enable access for the helper or Terminal, then rerun it. The helper never requests an Apple ID or password.

## 7. Manual Apple sync test

### Verify JSON without uploading

```bash
cd /Users/kaunghtetzaw/kobo-dashboard/mac-sync
TIMEZONE=Asia/Bangkok .build/release/KoboAppleSync --dry-run
```

The printed JSON should contain `syncedAt`, `reminders`, and `events`.

### Upload to Render

Replace the placeholder with the same secret stored in Render:

```bash
cd /Users/kaunghtetzaw/kobo-dashboard/mac-sync
APPLE_SYNC_SECRET='REPLACE_WITH_YOUR_SECRET' \
KOBO_SERVER_URL='https://kobo-dashboard-7ub6.onrender.com' \
TIMEZONE='Asia/Bangkok' \
.build/release/KoboAppleSync
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

## 9. KOReader and TRMNL configuration

1. Download the official [TRMNL KOReader repository](https://github.com/usetrmnl/trmnl-koreader) and extract it.
2. Connect the Kobo by USB.
3. Copy the inner `trmnl.koplugin` folder to:

   ```text
   /.adds/koreader/plugins/trmnl.koplugin/
   ```

4. Put the existing device API key by itself in:

   ```text
   /.adds/koreader/plugins/trmnl.koplugin/apikey.txt
   ```

   Alternatively, enter it under **Tools → TRMNL Display → Configure TRMNL → API Key**.
5. Safely eject the Kobo. Fully exit and reopen KOReader so it loads the plugin.
6. Under **Tools → TRMNL Display → Configure TRMNL**, set Base URL to:

   ```text
   https://kobo-dashboard-7ub6.onrender.com
   ```

   Do not append `/api/display`. Leave the MAC header name as `ID`.
7. Choose **Tools → TRMNL Display → Fetch screen now**.
8. After the landscape screen works, enable **Use server refresh interval** and **Enable auto-refresh**.

`GET /api/display` still accepts either a matching `access-token` or the configured `ALLOWED_DEVICE_ID`. It returns `image_url`, `filename`, and `refresh_rate: 1800`. The image URL is signed for five minutes because the plugin does not forward authentication headers when downloading it.

## 10. Landscape mode

The normal generated image is exactly **1024 × 758**. Begin with:

```text
KOBO_ROTATE_IMAGE=false
```

Set KOReader/Kobo to landscape orientation. If the plugin or framebuffer instead needs portrait pixel dimensions and the dashboard appears sideways, change Render to:

```text
KOBO_ROTATE_IMAGE=true
```

That rotates the completed landscape dashboard 90 degrees and serves a 758 × 1024 PNG. Change only this variable; the dashboard layout itself remains landscape.

## 11. Troubleshooting

### TRMNL returns HTTP 401

- Confirm the plugin API key matches `DEVICE_API_KEY`, or its detected MAC matches `ALLOWED_DEVICE_ID`.
- Leave the plugin's MAC header name set to `ID`.
- Do not add `/api/display` to Base URL.

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

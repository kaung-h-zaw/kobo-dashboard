# Kobo Dashboard

A small Node.js and Express dashboard and self-hosted TRMNL endpoint for a Kobo Nia running KOReader. It uses a fixed 758 × 1024, black-and-white layout designed for an e-ink screen. It does not need a database, Docker, or browser-side JavaScript.

## What it includes

- `/` — desktop browser preview of the Kobo-sized dashboard
- `/dashboard` — clean Kobo-friendly dashboard page
- `/api/dashboard` — date, time, events, tasks, and weather as JSON
- `/api/display` — authenticated TRMNL KOReader screen metadata
- `/screens/dashboard.png` — generated 758 × 1024 monochrome PNG
- `/health` — simple health check returning `{ "status": "ok" }`

The date and time are generated when a page, API, or screen-image request is made. Events, tasks, and weather are sample data in `server.js` for now. The PNG is rendered directly with Sharp; no browser automation is used.

## Run it locally

You need Node.js 18 or newer.

1. Open a terminal in this project folder.
2. Install the one dependency:

   ```bash
   npm install
   ```

3. Start the server:

   ```bash
   npm start
   ```

4. Open <http://localhost:3000> in your browser. The Kobo page is at <http://localhost:3000/dashboard>.

To test the authenticated TRMNL response locally, start the app with environment variables:

```bash
DEVICE_API_KEY=my-secret-key BASE_URL=http://localhost:3000 npm start
```

In another terminal, request a screen:

```bash
curl http://localhost:3000/api/display \
  --header "access-token: my-secret-key"
```

Stop the server by pressing `Ctrl+C` in the terminal.

## Push it to GitHub

Create an empty repository on GitHub first. Do not add a README or `.gitignore` there, because this project already has them. Then run these commands in the project folder, replacing the example URL with your repository URL:

```bash
git init
git add .
git commit -m "Create Kobo dashboard"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/kobo-dashboard.git
git push -u origin main
```

If the folder is already a Git repository, skip `git init`. If a remote named `origin` already exists, use `git remote set-url origin YOUR-REPOSITORY-URL` instead of `git remote add origin`.

## Deploy one free Web Service on Render

1. Sign in to [Render](https://render.com/) and connect your GitHub account.
2. In the Render dashboard, choose **New**, then **Web Service**.
3. Select your `kobo-dashboard` GitHub repository.
4. Use these settings:

   - **Runtime:** Node
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
   - **Instance Type:** Free

   Under **Advanced**, you can also set **Health Check Path** to `/health`.

   Add these environment variables:

   | Variable | Example | Purpose |
   | --- | --- | --- |
   | `DEVICE_API_KEY` | a long secret you choose | Must exactly match the plugin API key |
   | `BASE_URL` | `https://your-service.onrender.com` | Public service URL, with no path or trailing slash |
   | `TIMEZONE` | `Asia/Bangkok` | Time zone used for the dashboard |

5. Click **Create Web Service** and wait for the first deployment to finish.
6. Open the Render URL shown for the service. Add `/dashboard`, `/api/dashboard`, or `/health` to visit the other routes.

Only one Render Web Service is needed. Render supplies a `PORT` environment variable automatically; `server.js` reads it and binds to `0.0.0.0`, so no custom port setting is required. Do not add `PORT` yourself.

The dashboard defaults to Bangkok time when `TIMEZONE` is omitted. Another valid IANA time zone, such as `Europe/London`, can be used instead.

Render currently spins down a free Web Service after 15 minutes without inbound traffic, and waking it can take about a minute. That may matter later when choosing how often the Kobo refreshes.

## TRMNL protocol implemented here

The official KOReader plugin requests:

```text
GET <Base URL>/api/display
access-token: <API key>
```

Authentication is the raw device key in the `access-token` HTTP header. It is not a Bearer token. This server requires that header to exactly match `DEVICE_API_KEY`.

The broader TRMNL BYOS guide lists `/api/setup`, `/api/display`, and `/api/log` as minimum endpoints for official TRMNL firmware. The KOReader plugin's source only calls `/api/display` and then the returned image URL, so this lightweight KOReader backend intentionally does not add unused setup or log endpoints.

The plugin also sends `percent-charged`, `png-width`, `png-height`, `rssi`, `User-Agent`, and the device MAC address under `ID` by default when it can detect one. Those headers are useful device metadata but are not needed by this single-device server.

The successful response is:

```json
{
  "image_url": "https://your-service.onrender.com/screens/dashboard.png?v=...",
  "filename": "kobo-dashboard-YYYYMMDDHHMM.png",
  "refresh_rate": 1800
}
```

`image_url` is absolute. The plugin downloads that PNG in a second request and displays it full-screen. `filename` lets the plugin recognize a changed image, and `refresh_rate` is used when **Use server refresh interval** is enabled.

## Install and configure the KOReader plugin on Kobo

1. Download the official [TRMNL KOReader repository](https://github.com/usetrmnl/trmnl-koreader) as a ZIP and extract it on your computer.
2. Connect the Kobo by USB.
3. Copy the extracted `trmnl.koplugin` folder into the Kobo KOReader plugin directory so the complete path is:

   ```text
   /.adds/koreader/plugins/trmnl.koplugin/
   ```

   The `.adds` directory is hidden. Enable viewing hidden files in your computer's file manager if necessary. Do not copy the whole repository folder; copy the inner `trmnl.koplugin` folder.
4. Configure the same key used for Render's `DEVICE_API_KEY`. Either:

   - Create `/.adds/koreader/plugins/trmnl.koplugin/apikey.txt` containing only the key, with no quotes; or
   - Restart KOReader, then open **Tools → TRMNL Display → Configure TRMNL** and enter it under **API Key**.

5. In **Tools → TRMNL Display → Configure TRMNL**, set **Base URL** to your Render origin, for example:

   ```text
   https://your-service.onrender.com
   ```

   Do not add `/api/display`; the plugin adds that path itself. Leave **MAC address header name** as `ID`.
6. Save the settings and make sure the Kobo is connected to Wi-Fi.
7. Open **Tools → TRMNL Display → Fetch screen now**. The plugin should fetch the JSON metadata, download the PNG, and show it full-screen. Tap the image to close it.
8. For an always-on dashboard, enable **Use server refresh interval**, then choose **Tools → TRMNL Display → Enable auto-refresh**. Also enable KOReader's keep-alive option and disable automatic suspend.

If Fetch screen now reports HTTP 401, make sure the plugin API key and Render `DEVICE_API_KEY` match exactly. If it reports a connection or 404 error, check that Base URL is only the Render origin and that `/health` works in a normal browser.

## Official protocol sources

- [TRMNL KOReader README](https://github.com/usetrmnl/trmnl-koreader) — installation, settings, custom server endpoint, MAC header, and response fields
- [TRMNL KOReader development guide](https://github.com/usetrmnl/trmnl-koreader/blob/main/DEVELOPMENT.md) — request headers and response example
- [TRMNL KOReader request implementation](https://github.com/usetrmnl/trmnl-koreader/blob/main/trmnl.koplugin/main.lua) — exact HTTP request, authentication header, image download, caching, and refresh behavior
- [Official TRMNL BYOS API guide](https://docs.trmnl.com/go/diy/byos) — minimum BYOS endpoints and `ID` header
- [Official TRMNL Display API](https://docs.trmnl.com/go/private-api/screens) — `access-token` authentication and display response
- [Official TRMNL ImageMagick guide](https://docs.trmnl.com/go/imagemagick-guide) — monochrome PNG guidance

The next application step is replacing sample data with calendar, task, and weather integrations. Their secrets should remain in Render environment variables rather than being committed to GitHub.
# kobo-dashboard

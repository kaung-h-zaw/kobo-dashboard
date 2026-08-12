# Kaung Dashboard — standalone Kobo Nia app

Version 1 is a local, offline application launched from NickelMenu. It does not load KOReader or use KOReader runtime modules. It temporarily exits Nickel, draws directly through FBInk, reads the Kobo Nia touchscreen through Linux evdev, and restarts Nickel on exit.

## Architecture

- `start.sh` prevents duplicate instances, records framebuffer state, stops Nickel cleanly, and launches the bundled LuaJIT runtime.
- `app.lua` owns the blocking event loop and six fullscreen pages.
- `lib/input.lua` finds the touchscreen with FBInk's `input_scan`, handles the Nia Phoenix multitouch protocol, and normalizes raw coordinates.
- `lib/screen.lua` uses `fbdepth` canonical rotation and maps the same raw touch coordinates into the 1024×758 logical layout.
- `lib/renderer.lua` batches FBInk text and rectangle writes before refresh.
- `lib/state.lua` persists reminder and Kanban changes only when the user interacts.
- `nickel.sh` restarts the Kobo interface without rebooting.

## Interface system

All six pages use one TRMNL-inspired monochrome system adapted for an interactive Kobo: a compact black EXIT control, small uppercase labels, large primary values, strict one-pixel panels and dividers, restrained grayscale, and a light bottom title bar. The app recreates that visual language locally and does not use TRMNL branding, hosted assets, APIs, or runtime code.

- Home is a five-region mashup for date/time, weather, agenda, Kanban totals, and the daily quote.
- Calendar pairs a large month grid with a separate agenda column.
- Weather pairs a large current-condition panel with metric cells and a four-day forecast strip.
- Guest Wi-Fi gives each native-resolution QR code an equal, uncluttered panel.
- Reminders use Today and Upcoming columns with full-row touch targets.
- Kanban uses three status columns with high-contrast headers and compact task cards.

Runtime paths are fixed to:

```text
/mnt/onboard/.adds/kaungdashboard/
/mnt/onboard/.adds/nm/KaungDashboard
/tmp/kaungdashboard.pid
/tmp/kaungdashboard.lock
/tmp/kaungdashboard.stop
```

## Reminder completion rendering

The whole reminder row is tappable. An incomplete reminder has an empty box, black title, and no line. A completed reminder has an `X`, a gray title, and a black strike-through.

The strike-through is not a Unicode effect. FBInk's `--coordinates` result supplies the actual `lastRect_Left`, `lastRect_Top`, `lastRect_Width`, and `lastRect_Height` of the rendered title. The renderer draws a three-pixel black rectangle from the measured left edge to the measured right edge at the glyph rectangle's vertical midpoint. Tapping again clears the row and renders the normal title without that line.

When `PartialRefresh` is enabled, only the affected reminder row receives a GC16 refresh. Set it to `false` in `config.json` if the physical Nia shows objectionable row ghosting; the same interaction will then request a full flashing refresh.

Saved completion state lives in:

```text
/mnt/onboard/.adds/kaungdashboard/state-data.lua
```

## Obtain the standalone runtime tools

This project does not commit third-party ARM executables. Use the Kobo builds already published in the official `usetrmnl/trmnl-kobo` repository:

```bash
cd /tmp
git clone --depth 1 https://github.com/usetrmnl/trmnl-kobo.git
```

The installer copies `luajit`, `fbink`, `fbdepth`, and `input_scan` into this app's own directory. After installation, the dashboard does not depend on TRMNL or KOReader and performs no network requests.

## Install from macOS or Linux

1. Connect the Kobo by USB and tap **Connect**.
2. Confirm its mounted path. On macOS this is normally `/Volumes/KOBOeReader`.
3. Run the preparation script explicitly:

   ```bash
   cd /Users/kaunghtetzaw/kobo-dashboard/kobo-app
   ./install.sh /Volumes/KOBOeReader /tmp/trmnl-kobo
   ```

4. Verify these files exist:

   ```text
   KOBOeReader/.adds/kaungdashboard/start.sh
   KOBOeReader/.adds/kaungdashboard/bin/luajit
   KOBOeReader/.adds/kaungdashboard/bin/fbink
   KOBOeReader/.adds/kaungdashboard/bin/fbdepth
   KOBOeReader/.adds/kaungdashboard/bin/input_scan
   KOBOeReader/.adds/nm/KaungDashboard
   ```

5. Safely eject `KOBOeReader`, then unplug it. NickelMenu notices config changes automatically; if the item does not appear after a short wait, restart the Kobo once.
6. Select **NickelMenu → Kaung Dashboard**.

No installer is run automatically by this repository.

## Controls

- Swipe left: next page.
- Swipe right: previous page.
- Page order: Weather → Calendar → Home → Guest Wi-Fi → Reminders → Kanban.
- First/last pages do not wrap by default.
- Tap any reminder row to toggle completion and its measured strike-through.
- Tap a Kanban card to advance it. Done remains Done by default.
- Tap the visible **EXIT** button on any page to return to Nickel.
- Backup exit: press and hold the top-left EXIT corner for three seconds.

## Quote and Guest Wi-Fi

Home includes a local quote-of-the-day panel. Its seven short messages rotate by calendar day and require no network connection. If Home remains open across midnight, the page redraws once to show the next quote.

Guest Wi-Fi is one swipe right from Home. It shows separate, permanently saved QR codes for `Kaung_2.4G` and `Kaung_5G`. The 1-bit PNG files are drawn at their native 296×296 resolution so their module grid remains sharp. The written password is not shown, but it is encoded in each QR image. The two generated PNGs are intentionally ignored by Git and still copied to the Kobo by the installer; treat the local files in `assets/` as private credentials.

The QR content is static. It is drawn only when the Guest Wi-Fi page opens and does not receive its own timed updates.

## E-ink refresh cadence

- The small clock region receives one partial refresh per minute.
- A clean full-screen refresh replaces every fifteenth clock update to limit ghosting.
- Opening the app, changing pages, changing a Kanban state, and the daily Home quote change use a full refresh.
- Reminder completion uses the configured row-only partial refresh.
- The Wi-Fi QR codes and other unchanged content are not redrawn every minute.

Both clock values are configurable. Physical Nia testing should confirm whether the fifteen-minute cleanup cadence is comfortable.

## Configuration

Edit `/mnt/onboard/.adds/kaungdashboard/config.json` while connected by USB:

```json
{
  "Orientation": "landscape-right",
  "StartPage": "home",
  "WrapPages": false,
  "KanbanCycleDoneToTodo": false,
  "PartialRefresh": true,
  "ClockRefreshMinutes": 1,
  "FullRefreshMinutes": 15,
  "SwipeThreshold": 120,
  "TapSlop": 28,
  "CornerExitHoldSeconds": 3,
  "Debug": true
}
```

Supported orientations are `portrait`, `landscape-right`, and `landscape-left`.

## Recovery

If the app is responsive, use EXIT or hold the top-left corner. If an SSH/telnet session is available, request a graceful stop:

```sh
/mnt/onboard/.adds/kaungdashboard/stop.sh
```

The app polls for that request every 500 ms. After eight seconds, `stop.sh` sends TERM as a fallback; `start.sh` still restores the original framebuffer bit depth/rotation and restarts Nickel through its cleanup trap.

If neither touch nor remote access works, hold the Kobo power button until it powers off, then start it normally. The dashboard does not modify boot files or autostart settings, so it will not relaunch by itself.

Logs are available at:

```text
/mnt/onboard/.adds/kaungdashboard/debug.log
```

## Uninstall

Connect by USB and remove only:

```text
KOBOeReader/.adds/kaungdashboard/
KOBOeReader/.adds/nm/KaungDashboard
```

Safely eject and restart the Kobo. Do not remove the complete `.adds` or `.adds/nm` directory.

## Physical Kobo Nia test checklist

The Mac tests syntax and state/gesture logic, but it cannot test the Nia framebuffer or evdev device. On the Kobo verify:

1. Nickel exits and the Home page appears at 1024×758 in the requested direction.
2. Touch targets align with their rendered positions, especially all four corners.
3. Short motion is ignored and left/right swipes respect non-wrapping boundaries.
4. Each reminder row toggles, the black line crosses the title midpoint, and the row-only refresh is clean.
5. Reminder state remains after exiting and relaunching.
6. Kanban transitions persist and Done cards remain Done.
7. EXIT and the three-second corner hold both restore Nickel without rebooting.
8. A forced stop or Lua error still restores framebuffer rotation and Nickel.
9. The app remains idle without high CPU use; input polling blocks for up to 500 ms.
10. Both Wi-Fi QR codes scan from the e-ink display and connect to the correctly labelled network.
11. The clock updates once per minute without redrawing the QR area, and a clean refresh occurs after fifteen updates.

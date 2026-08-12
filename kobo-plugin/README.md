# Kaung Dashboard KOReader plugin — Version 1

This folder contains a completely local KOReader plugin for the Kobo Nia. It does not contact Render, Apple services, TRMNL, or a weather API. All displayed content is mock data; only reminder completion and Kanban status are writable.

## Install on a Kobo

1. Connect the Kobo to the computer by USB and choose **Connect** on the device.
2. In the mounted `KOBOeReader` drive, show hidden files if `.adds` is not visible.
3. Copy the entire `kaungdashboard.koplugin` directory—not only its contents—to:

   ```text
   KOBOeReader/.adds/koreader/plugins/kaungdashboard.koplugin
   ```

   From this repository on macOS, if the mounted drive is at the normal path:

   ```bash
   cp -R /Users/kaunghtetzaw/kobo-dashboard/kobo-plugin/kaungdashboard.koplugin \
     /Volumes/KOBOeReader/.adds/koreader/plugins/
   ```

4. Safely eject `KOBOeReader`, unplug it, and restart KOReader.
5. Open KOReader's main menu, go to **More tools**, and tap **Kaung Dashboard**.

The plugin opens on **Home** and rotates a portrait screen clockwise into landscape. Tap the outlined **EXIT** control or use KOReader's Back button/gesture to return. The previous orientation is restored on exit.

## Use

- Swipe left: Weather → Calendar → Home → Reminders → Kanban.
- Swipe right: move in the opposite direction.
- Page navigation wraps at both ends by default.
- Tap a reminder row or checkbox to toggle it.
- Tap a Kanban card to move To Do → In Progress → Done.
- Done cards remain Done by default.

Small swipes under 12% of the screen width are ignored. The swipe hint disappears after three successful page changes. Reminder and Kanban state is persisted by KOReader in `settings/kaungdashboard.lua`; no keyboard is used.

## Configuration

Edit `kaungdashboard.koplugin/config.lua` before copying the plugin, then restart KOReader:

- `wrap_pages = false` stops at Weather and Kanban.
- `done_cycles_to_todo = true` makes a tap on Done cycle back to To Do.
- `landscape_rotation = "counter_clockwise"` rotates the other way.
- `minimum_swipe_distance_ratio` changes accidental-swipe filtering.

## E-ink refresh behavior

- Opening, closing, and page changes request KOReader's `flashui` refresh for a clean screen.
- Reminder changes request a region-limited `ui` refresh for the touched row.
- Kanban changes request a `ui` refresh for the content area because a card changes sections.

These are KOReader-supported refresh modes. The best full-refresh cadence still depends on the Kobo/KOReader version, so ghosting and touch alignment must be checked on the physical Nia.

## Uninstall

Connect the Kobo by USB, remove only this folder, safely eject, and restart KOReader:

```text
KOBOeReader/.adds/koreader/plugins/kaungdashboard.koplugin
```

Optional: remove `.adds/koreader/settings/kaungdashboard.lua` to erase the saved mock completion/status state. Do not remove the whole `plugins` or `settings` directory.

## Physical-device test checklist

1. Confirm the plugin is listed and opens without an error dialog.
2. Confirm the logical screen is landscape and touch coordinates match controls.
3. Swipe through all five pages in both directions, including both wrap boundaries.
4. Try a very short horizontal motion and confirm it does not change pages.
5. Toggle every reminder twice and restart KOReader to verify persistence.
6. Advance each Kanban card and restart KOReader to verify persistence.
7. Confirm no keyboard appears anywhere.
8. Inspect row updates and card moves for ghosting.
9. Exit with both the visible control and KOReader Back; confirm the old orientation returns.

KOReader itself is not bundled in this repository, so framebuffer rendering, rotation direction, touch calibration, and real e-ink refresh quality require this physical test.

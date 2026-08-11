# Kobo Apple Sync Helper

This macOS app-bundled command-line helper uses Apple's public EventKit framework to read incomplete Reminders and Calendar events, then posts them to the Kobo dashboard. The `.app` bundle gives macOS TCC a stable identity for the Calendar and Reminders permission prompts. It never asks for or stores an Apple ID or password.

See the project root `README.md` for complete setup, permission, testing, and LaunchAgent instructions.

Quick commands:

```bash
./scripts/build-app.sh
./scripts/request-permissions.sh
TIMEZONE=Asia/Bangkok ./scripts/run-sync.sh --dry-run
APPLE_SYNC_SECRET='your-secret' \
KOBO_SERVER_URL='https://kobo-dashboard-7ub6.onrender.com' \
TIMEZONE=Asia/Bangkok \
./scripts/run-sync.sh
```

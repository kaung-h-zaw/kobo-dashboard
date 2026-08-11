# Kobo Apple Sync Helper

This macOS command-line program uses Apple's public EventKit framework to read incomplete Reminders and Calendar events, then posts them to the Kobo dashboard. It never asks for or stores an Apple ID or password.

See the project root `README.md` for complete setup, permission, testing, and LaunchAgent instructions.

Quick commands:

```bash
swift build -c release
TIMEZONE=Asia/Bangkok .build/release/KoboAppleSync --dry-run
APPLE_SYNC_SECRET='your-secret' \
KOBO_SERVER_URL='https://kobo-dashboard-7ub6.onrender.com' \
TIMEZONE=Asia/Bangkok \
.build/release/KoboAppleSync
```


# Runtime binaries

This directory intentionally does not commit third-party ARM executables. Before installing on the Kobo, populate it with these Kobo builds from the official `usetrmnl/trmnl-kobo` bundle:

```text
luajit
fbink
fbdepth
input_scan
```

The repository-level `kobo-app/install.sh` copies them from a local `trmnl-kobo` checkout and preserves their upstream licenses. At runtime the dashboard uses only its own copies and has no KOReader or TRMNL dependency.

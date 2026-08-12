# Private Wi-Fi QR assets

Place these two locally generated 1-bit PNG files in this directory before running the Kobo installer:

- `wifi-24ghz.png`
- `wifi-5ghz.png`

They are intentionally ignored by Git because each QR code contains a Wi-Fi password. Generate them locally with `qrencode`, use error-correction level M, an eight-pixel module size, and the standard four-module quiet zone. The installer copies the complete `kaungdashboard` directory, including these local files, to the Kobo.

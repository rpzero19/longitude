# App Store screenshots

Two sets, because App Store Connect has a separate upload slot per display size
and rejects anything that doesn't match the slot exactly.

| Folder | Pixels | Slot in App Store Connect | Captured on |
|---|---|---|---|
| `6.9-inch/` | 1320 × 2868 | iPhone 6.9" Display | iPhone 17 Pro Max |
| `6.7-inch/` | 1284 × 2778 | iPhone 6.7" Display | iPhone 14 Plus |

Upload each folder into its matching tab. The 6.9" set is the one Apple currently
requires; the 6.7" set covers the older slot if that's the tab you're on.

## Regenerating

Don't recapture by hand. The app takes launch arguments so the whole set is scriptable:

```bash
xcrun simctl launch <sim> io.github.rpzero19.longitude              # results list
xcrun simctl launch <sim> io.github.rpzero19.longitude -openSeries ldl
xcrun simctl launch <sim> io.github.rpzero19.longitude -openSeries vitd
xcrun simctl launch <sim> io.github.rpzero19.longitude -initialTab 1
xcrun simctl io <sim> screenshot out.png
```

`-openSeries` takes any registry id: `ldl`, `hgb`, `hba1c`, `vitd`, `tsh`, `alt`…

# Couple App branding direction

This change prepares the final branding system without shipping the final launcher icon, native splash, or release artwork.

## Identity

| Area | Direction |
|------|-----------|
| Mood | Warm clinic, soft floral, romantic, clean, premium-minimal. |
| Core symbol | Minimal tooth with a subtle heart and lily/petal accents. |
| Primary color | Melon pink `#FD8392`. |
| Supporting colors | Lily pink, warm cream, soft lavender, dental mint. |
| Visual weight | Gentle and readable first; decoration stays secondary. |

## Asset structure

```text
assets/branding/
  icons/
  splash/
  illustrations/
```

Use these folders only for branding-safe artwork. Do not mix user uploads, backup files, or generated app data into this tree.

## Launcher icon rules

The final icon should be prepared later as separate assets:

- `icons/foreground` — tooth/heart/petal mark, transparent background.
- `icons/background` — solid or soft gradient melon/cream background.
- `icons/monochrome` — Android 13+ single-color silhouette.

Constraints:

- Keep the tooth recognizable at small sizes.
- Avoid tiny text.
- Avoid detailed flowers that disappear at launcher size.
- Keep enough safe area for adaptive icon masks.

## Splash rules

The splash should use:

- warm cream or theme-aware dark background;
- the reusable brand mark;
- short fade/scale motion;
- no network dependency;
- no long artificial delay.

Flutter currently uses `LilySplash` with `BrandMark`. Native splash generation is intentionally out of scope.

## Implementation hooks

| File | Purpose |
|------|---------|
| `lib/config/branding.dart` | Central display name, brand colors, radii, shadow, splash timing, and placeholder asset paths. |
| `lib/shared/widgets/brand_mark.dart` | Reusable vector-like brand mark until final assets exist. |
| `lib/shared/widgets/lily_splash.dart` | Splash integration using branding constants. |
| `assets/branding/**` | Reserved folders for final icon/splash/illustration files. |

## Out of scope for this change

- Final launcher icon PNGs.
- `flutter_launcher_icons`.
- Native splash generation.
- Release signing.
- Cloud or backup integration.

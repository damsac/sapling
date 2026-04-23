# Sapling — Design System

## Brand Identity

Sapling is built for outdoorsy, "granola" people — hikers, trail runners, foragers, and anyone who spends meaningful time in nature. The design should feel **soft, inviting, and earthy** while remaining simple and functional. Think field journal meets modern mobile app: warm textures, organic shapes, and a palette drawn from the natural world.

---

## Color Palette — Field Journal

| Role | Name | Hex | Usage |
|------|------|-----|-------|
| Primary / Brand | Forest Green | `#4a6741` | Record button, CTAs, active states, brand accents |
| Accent | Amber | `#c4863a` | Secondary highlights, warnings, seed pins |
| Tertiary | Bark | `#7a6840` | Trail lines, tertiary text, decorative elements |
| Background | Parchment | `#f4f0e8` | Sheet backgrounds, cards |
| Surface | Stone | `#ede9e0` | Stat cards, input backgrounds, secondary surfaces |
| Text | Ink | `#2d2a22` | Primary text |

### Usage Notes
- Use Forest Green (`#4a6741`) for all primary interactive elements (record button, save buttons, brand-colored capsule badges).
- Amber (`#c4863a`) is the accent — use sparingly for secondary actions or callouts.
- Never use pure black or pure white — always pull from the warm palette above.
- System materials (`.regularMaterial`, `.thinMaterial`) should be used for floating panels and overlays so dark/light mode works automatically. The underlying tint from the palette will bleed through subtly.

---

## Typography

- **Font**: SF Pro Rounded (`.fontDesign(.rounded)` in SwiftUI) — applied globally
- **Hierarchy**:
  - Titles: `.title2.weight(.bold)`
  - Section headers: `.headline.weight(.semibold)`
  - Body: `.body`
  - Labels / captions: `.caption` / `.caption2`
  - Numeric stats: `.title3.monospacedDigit()` — always monospaced for alignment

---

## Shape Language

- **Buttons**: Capsule shape for badges/tags; `RoundedRectangle(cornerRadius: 12–14)` for action buttons
- **Cards / panels**: `RoundedRectangle(cornerRadius: 14–16)` with system material backgrounds
- **Bottom sheets**: `RoundedRectangle(cornerRadius: 20)` top corners, drag indicator pill
- **Map pins / seed markers**: Filled circles with white border and subtle drop shadow
- **Icon buttons**: 40×40pt circles with `.thinMaterial` background and drop shadow

---

## Map Style

The map uses **OpenFreeMap Liberty** tile style (`https://tiles.openfreemap.org/styles/liberty`). This provides:
- Full topographic accuracy (elevation contours, terrain shading)
- Standard road and trail labeling
- Accurate satellite-derived data

**Do not apply any hand-drawn or stylized map overlays.** The tile style may look clean/minimal by nature, but it is fully accurate. Functionality and legibility always take priority over aesthetic stylization on the map layer.

Trail lines drawn by Sapling use `SaplingColors.trailUI` (a bright, high-contrast color) at 4pt width with round caps/joins so they're clearly readable over any basemap.

---

## UI Components

### Bottom Sheets
- Drag indicator: `Capsule` 36×5pt, `.secondary.opacity(0.4)`, centered at top
- Background: `.regularMaterial`
- Presented with `.presentationDetents([.medium, .large])`

### Stat Cards
- `LazyVGrid` with flexible columns
- Each cell: value in `.title3.monospacedDigit().semibold`, label in `.caption2.secondary`
- Card background: `.regularMaterial` in `RoundedRectangle(cornerRadius: 14)`, 16pt internal padding

### Action Buttons (primary)
- Full-width, `RoundedRectangle(cornerRadius: 12–14)`, Forest Green background, white text
- Vertical padding: 12–14pt

### Action Buttons (secondary / cancel)
- Full-width, `RoundedRectangle(cornerRadius: 12–14)`, `.regularMaterial` background, `.secondary` text

### Edit / Tag Badges
- Capsule shape
- Brand color fill at 12% opacity + brand color text (e.g. `SaplingColors.brand.opacity(0.12)`)

### Floating Map Buttons (top bar)
- 40×40pt circle, `.thinMaterial`, shadow `radius: 4, y: 2, opacity: 0.15`

### Record Button
- 64×64pt circle, Forest Green fill, white icon
- Stop state: red fill (`SaplingColors.stopRecording`)

---

## Spacing & Layout

- Screen edge padding: **16pt horizontal**
- Stack spacing between major sections: **20pt**
- Internal card padding: **16pt**
- Bottom safe-area clearance: **24pt minimum**

---

## Tone

- Functional first — information density matters on trail
- Warm but not cutesy — no excessive emojis or playful copy
- Labels should be clear and brief (e.g. "Distance", "Gain", "Time" — not "Total Distance Traveled")
- Errors and confirmations should be direct and calm

---

## SaplingColors Reference (Swift)

```swift
// Primary brand green
static let brand = Color(red: 0.290, green: 0.404, blue: 0.255)  // #4a6741

// Accent amber
static let accent = Color(red: 0.769, green: 0.525, blue: 0.227)  // #c4863a

// Trail line on map (high visibility)
static let trailUI = Color(...)  // current value — keep high-contrast

// Recording states
static let recording = brand
static let stopRecording = Color.red
```

---

## What to Avoid

- **No pure black/white** — always use warm palette equivalents
- **No hand-drawn map overlays** — accuracy is non-negotiable
- **No heavy drop shadows** — subtle only (opacity ≤ 0.2)
- **No excessive blur layers** — one material level per floating surface
- **No decorative icons in stat cells** — numbers speak for themselves
- **No color for decoration only** — every use of brand color should indicate interactivity or status

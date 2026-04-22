# Sapling — Navigation & Screen Mockups

## Tab Structure

```
┌─────────────────────────────────┐
│                                 │
│           [content]             │
│                                 │
├─────────────────────────────────┤
│   🗺  Map   │  🔍 Explore │ 🌱  │
│  (active)  │             │ soon│
└─────────────────────────────────┘
```

Three tabs total. Map and Explore ship now. Community (🌱) ships in Phase 3 — the tab slot is reserved so navigation doesn't need to be restructured later.

---

## Tab 1 — Map

The live view. Everything happens here while you're in the field.

```
┌─────────────────────────────────┐
│  ≡  Sapling          ⊕  📍     │  ← hamburger (settings) + snap-to-location
├─────────────────────────────────┤
│                                 │
│                                 │
│        [ MapLibre map ]         │
│                                 │
│          • seed dot             │
│    ~~~~~~~~ trail ~~~~~~~~      │
│                                 │
│                                 │
│                         [📍]    │  ← recenter button
├─────────────────────────────────┤
│  ● Recording                    │
│  2.4 mi · 1:03:22 · +340 ft    │  ← live stats bar (while recording)
│  [  Pause  ]   [ Drop Seed ▾ ] │
└─────────────────────────────────┘
```

**States:**
- **Idle** — map only, floating [Start Trip] button bottom-center
- **Recording** — live stats bar slides up from bottom
- **Route Building** — tap-to-place waypoints, dashed preview line, distance shown
- **Viewing Saved Route** — route overlaid on map, non-interactive stats drawer

---

## Tab 2 — Explore

Planning and history. No map interaction — browse before you go.

```
┌─────────────────────────────────┐
│  Explore                  🔍   │
├─────────────────────────────────┤
│  ┌──────────────────────────┐   │
│  │ 🔎  Search trails...     │   │  ← trail search (Overpass/OSM)
│  └──────────────────────────┘   │
│                                 │
│  MY TRIPS              [+ New] │
│  ┌──────────────────────────┐   │
│  │ 🗓 Apr 18 · Sky Pond     │   │
│  │ 8.2 mi · +2,100 ft      │   │
│  └──────────────────────────┘   │
│  ┌──────────────────────────┐   │
│  │ 🗓 Apr 12 · Bear Lake    │   │
│  │ 4.1 mi · +680 ft        │   │
│  └──────────────────────────┘   │
│                                 │
│  SAVED ROUTES                   │
│  ┌──────────────────────────┐   │
│  │ 📍 Longs Peak Loop       │   │
│  │ 14.6 mi · +5,200 ft     │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

**Tap a trip** → full summary sheet (current `TripSummarySheet`) with map, stats, elevation profile, seeds.

**Tap a saved route** → route detail sheet with elevation profile + [Start Navigation] button that switches to Map tab with the route loaded.

**Search** → trail results list → tap to preview on mini-map → [Save Route] or [Navigate].

---

## Tab 3 — Community (Phase 3 placeholder)

```
┌─────────────────────────────────┐
│  Community                      │
├─────────────────────────────────┤
│                                 │
│         🌱                      │
│                                 │
│    Community seeds are          │
│    coming soon.                 │
│                                 │
│    When it launches, you'll     │
│    find water sources, camp     │
│    spots, and hidden gems        │
│    shared by people you trust   │
│    — with fuzzy locations so    │
│    wild places stay wild.       │
│                                 │
│    [ Join the waitlist ]        │
│                                 │
└─────────────────────────────────┘
```

Ships as a locked tab in Phase 2 so users know it's coming. Unlocks in Phase 3.

---

## Sheet Flows (Modal, not tabs)

These present as bottom sheets over any tab:

```
TripSummarySheet          RouteDetailSheet         SeedDetailSheet
─────────────────         ────────────────         ───────────────
[drag handle]             [drag handle]            [drag handle]
Mini map (220pt)          Mini map (220pt)         Seed type icon
Trip name + edit          Route name + edit        Title + notes
Stats grid                Stats grid               Conditions log
Elevation profile         Elevation profile        [Edit] [Delete]
Seed list                 [Start Navigation]
[Done]                    [Export GPX]
```

---

## Navigation Flow Diagram

```
App Launch
    │
    ├─► Map Tab (default)
    │       │
    │       ├─► [Start Trip] ──► recording mode
    │       │       └─► [Finish] ──► TripSummarySheet (modal)
    │       │                           └─► [Done] back to Map
    │       │
    │       ├─► [Build Route] ──► route building mode
    │       │       └─► [Save] ──► name prompt ──► back to Map
    │       │
    │       └─► tap seed dot ──► SeedDetailSheet (modal)
    │
    └─► Explore Tab
            │
            ├─► My Trips list ──► TripSummarySheet (modal)
            │
            ├─► Saved Routes list ──► RouteDetailSheet (modal)
            │       └─► [Start Navigation] ──► switches to Map Tab
            │
            └─► Search ──► trail results ──► RouteDetailSheet (modal)
```

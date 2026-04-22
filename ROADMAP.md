# Sapling — Product Roadmap

## Vision

Sapling is the field journal for people who go off the beaten path. It records where you've been, helps you plan where you're going, and lets you share hidden gems with people you trust — without publishing exact GPS coordinates that turn wild places into tourist destinations.

The gap we fill: **social-first backcountry tools that respect wild places.** AllTrails publishes everything and drives crowding. Gaia has no soul. FarOut is locked to established long trails. Nobody has built a tool for the person who wants to find their own adventures and share them carefully.

---

## Navigation Structure

Three tabs — Map and Explore ship in Phase 2, Community reserved for Phase 3.

| Tab | Ships | Purpose |
|---|---|---|
| **Map** | Now | Live recording, seed dropping, route building |
| **Explore** | Phase 2 | Trip history, saved routes, trail search |
| **Community** | Phase 3 | Fuzzy seeds, trusted sharing, conditions |

The Community tab ships as a locked placeholder in Phase 2 so the nav structure doesn't need to change later. Full mockups and flow diagrams: [`docs/mockups.md`](docs/mockups.md).

---

## Phases

### ✅ Phase 1 — Foundation (complete)
- GPS track recording with live stats (distance, elevation gain, time)
- Seeds / waypoint dropping during or after a trip
- Seed types: Water, Camp, Beauty, Service, Custom
- Offline map download
- Trip history with summary stats
- Field Journal design system (warm palette, no system materials)

---

### 🔨 Phase 2 — Planning (in progress)

Turn Sapling from a recording tool into a planning tool. Without this, users still need AllTrails or Gaia before they open Sapling.

**Trail Search**
- Search trails by name, location, or region
- Filter by distance, elevation gain, difficulty, features (water, camping, dogs)
- Data source: OpenStreetMap/Overpass API or licensed trail database
- Show trail on map with stats before committing

**Route Builder** ✅
- Draw a custom route on the map (tap to add points)
- Or import a GPX/KML file
- Show full elevation profile (chart with gain/loss markers)
- Calculate total distance, estimated time, elevation stats
- Save as a "planned trip" (distinct from a recorded trip)

**Multi-Day Trip Planner**
- Break a route into daily segments
- Assign Seeds to each day (camp spots, water sources, bailout points)
- See per-day stats: distance, gain, estimated hours
- Export the full plan as GPX for use in other tools

**Offline Maps — One-Tap Flow**
- "Download area for this route" button on any planned or recorded trip
- Automatically calculates bounding box + buffer and downloads
- Current manual bounding box flow stays for power users

**GPX/KML Export**
- Export any recorded or planned trip as GPX
- Export Seeds as waypoints embedded in the GPX file

---

### 👥 Phase 3 — Trusted Seeds (Social)

The core differentiator. Built around trust and restraint rather than virality.

**User Accounts**
- Sign up / sign in (email or Apple ID)
- Profile: name, bio, home region, trip count
- Follow other users (asymmetric, like Twitter — not mutual friends)

**Seed Sharing Tiers**

| Tier | Visibility | Mechanic |
|---|---|---|
| **Private** | Just you | Default. Your seeds stay yours. |
| **Trusted Circle** | People you explicitly share with | Share a specific seed or trip with named users. Like AirDrop for trail intel. |
| **Community Seeds** | All users, fuzzy location | Seed appears on others' maps within a ~500m radius — people have to do some adventuring to find the actual spot. No exact coordinates published. |
| **Verified Gems** | All users, curated | Sapling staff or community-nominated spots vetted for resilience to traffic. Higher confidence, still fuzzy. |

**Fuzzy Location** is the key mechanic. A shared seed shows up as a shaded circle on the map — "there's something worth finding in this area" — but the exact pin is hidden until you're physically within range (geofenced reveal). This preserves the discovery experience and disincentivizes driving crowds to fragile places.

**Conditions & Comments**
- Users can leave time-stamped conditions on any shared seed: "water flowing as of June 2026", "trail washed out above 9k"
- Conditions expire after 90 days and prompt for an update

**Trip Sharing**
- Share a full recorded trip (track + seeds) with a link or directly to followers
- Viewer sees the route and public seeds; private seeds stay hidden

---

### 🧠 Phase 4 — Intelligence

**Weather**
- Weather overlay on the map (precip, wind, temperature by day)
- 7-day forecast anchored to planned trip waypoints
- Source: Open-Meteo or NOAA

**Trail Conditions Feed**
- Community-reported: snow level, water availability, blowdowns, permit status
- Aggregated per trail, not per seed
- Decay function: old reports shown with lower confidence

**Permit Integration**
- Flag trailheads that require permits
- Link to recreation.gov permit page
- Eventually: availability calendar overlay on map

**Resupply Points** (for thru-hikers)
- Mark towns, post offices, outfitters as resupply seeds
- Distance-to-resupply counter during recording

---

## What Makes Us Different

| Feature | AllTrails | Gaia GPS | FarOut | **Sapling** |
|---|---|---|---|---|
| Trail discovery | ✅ 500k trails | ⚠️ smaller DB | ✅ long trails | Phase 2 |
| Offline maps | ⚠️ paid only | ✅ | ✅ | ✅ |
| Route planning | ⚠️ basic | ✅ | ⚠️ | Phase 2 |
| GPS recording | ✅ | ✅ | ⚠️ | ✅ |
| Social sharing | ✅ public everything | ❌ | ⚠️ | ✅ **fuzzy, trust-based** |
| Community intel | ✅ reviews/photos | ❌ | ✅ water/shelter | Phase 3 |
| Respects wild places | ❌ drives crowding | n/a | ✅ thru-trails only | ✅ **by design** |
| Multi-day planning | ⚠️ basic | ✅ | ⚠️ | Phase 2 |
| Elevation profiles | ✅ | ✅ | ✅ | Phase 2 |

---

## Now Building

See open PRs and issues for current in-progress work.

When picking the next thing to build, prioritize in this order:
1. Does it unblock users from needing another app?
2. Does it deepen the Seeds ecosystem (our moat)?
3. Does it ship fast enough to get real user feedback?

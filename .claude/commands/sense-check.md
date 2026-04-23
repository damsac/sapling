# /sense-check — Reground the session

You are doing a holistic sense check on the current state of Sapling. The goal is to make sure the work in progress is actually moving the app toward completion, and to flag if we've drifted.

## Steps

### 1. Read the vision and priorities
Read `ROADMAP.md` in full. Internalize:
- The core vision: field journal for off-the-beaten-path adventurers, trust-based sharing, respects wild places
- The priority filter: (1) unblocks users from needing another app, (2) deepens the Seeds ecosystem, (3) ships fast enough for real feedback
- Which phase we're in and what defines "done" for it

### 2. Survey current work
```bash
git log --oneline -10
git diff main..HEAD --stat
gh pr list --state open
```

### 3. Check for scope creep or drift
Look at what's been built recently and ask:
- Does this directly serve the vision, or is it polish/infrastructure that could wait?
- Is the current feature complete enough to be useful, or is it a half-built abstraction?
- Are we building things users will actually need in the next 30 days of using the app?
- Are we over-engineering the Rust layer, or building UI that doesn't yet have a backend?

### 4. Assess the critical path to a shippable Phase 2
Phase 2 is "Planning" — turning Sapling from a recording tool into a planning tool. The minimum slice that achieves this:
- A user can draw or import a route on the map
- They can see the elevation profile and stats for that route
- They can save it and use it as a trip plan (not just a recorded trip)

Ask: Is what we're building right now on the critical path to this? If not, why not?

### 5. Check for technical debt that could block progress
```bash
cargo test -p sapling-core 2>&1 | tail -5
```

Are there known bugs, failing tests, or architectural decisions that will slow us down later?

---

## Output format

```
## Sense Check

**Vision alignment:** <Green / Yellow / Red> — <1-sentence reason>

**Current work:** <What are we actually building right now and why>

**Is this the right thing?** <Yes / Partially / No> — <honest 2-3 sentence assessment>

**Critical path status:**
- [ ] Route drawing on map
- [ ] Elevation profile for planned routes
- [ ] Save/load planned trips
- [x] GPX import (done — shortcut for this)

**Drift risk:** <What might be pulling us off course, if anything>

**Recommendation:** <One clear call — stay the course, refocus on X, or defer Y>
```

Be honest. If we're building the wrong thing, say so directly. The goal is shipping a real app, not accumulating features.

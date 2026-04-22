# /stop — End a work session

You are wrapping up a Sapling dev session. Execute every step below in order.

## Steps

### 1. Assess what was built this session
Review all changes since the last commit:
```bash
git diff --stat
git status
```

Also review the full diff to understand what changed:
```bash
git diff
```

### 2. Run a build check
Verify the Rust core compiles and tests pass before committing:
```bash
cd /Users/isaacwallace-menge/sapling && cargo test -p sapling-core 2>&1 | tail -10
```

If tests fail, flag the failures and ask the developer if they want to fix before committing or commit with a note.

### 3. Stage and commit
Stage only the relevant changed files (never `git add .` blindly — check for build artifacts, temp files, `.env`):
```bash
git status
```

Then commit with a descriptive message following the project's commit style (`feat:`, `fix:`, `refactor:`):
- Lead with what changed and why
- Reference the roadmap phase if relevant (e.g. "Phase 2 — Route Builder")
- Include `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`

### 4. If xcframework was rebuilt, confirm bindings are committed
```bash
ls -la ios/Bindings/
git diff --stat ios/Bindings/ ios/Frameworks/
```

If the xcframework or Swift bindings changed, make sure they're included in the commit.

### 5. Push and update the PR
```bash
git push
gh pr list --state open
```

If a PR exists for this branch, check if its description needs updating to reflect new work:
```bash
gh pr view --json title,body
```

Update the PR description with any new features or test steps added this session:
```bash
gh pr edit <number> --body "..."
```

If no PR exists yet, create one.

### 6. Update ROADMAP.md
Check whether any phase items were completed this session. If so, update their status markers (`🔨` → `✅`) in `ROADMAP.md` and commit:
```bash
# Only if roadmap status changed
git add ROADMAP.md
git commit -m "docs: update roadmap status after session"
git push
```

### 7. Update CLAUDE.md if needed
If this session introduced new architectural patterns, new conventions, new build steps, or new devices/IDs that future sessions need to know, update `CLAUDE.md` accordingly and commit.

### 8. Session summary
End with a brief wrap-up:

```
## Session Summary

**Committed:** <what was committed, 1-2 sentences>
**PR:** <link>
**Roadmap progress:** <what phase items moved forward or completed>

**Left for next session:** <any in-flight work, TODOs, or things to verify>
**Known issues:** <anything broken or deferred>
```

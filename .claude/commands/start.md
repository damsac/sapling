# /start — Begin a work session

You are starting a Sapling dev session. Execute every step below in order, then give the developer a focused briefing.

## Steps

### 1. Sync with remote
```bash
git fetch --all
git status
git log --oneline -1
```

Check which branch we're on. If on `main`, ask the developer which feature branch to check out. If already on a feature branch, pull latest:
```bash
git pull
```

### 2. Read current state
- Read `CLAUDE.md` and `ROADMAP.md` to ground yourself in the project rules and priorities.
- Read the last commit message and `git diff main..HEAD --stat` to understand what the current branch contains.

### 3. Check for open PRs and in-flight work
```bash
gh pr list --state open
gh pr view --json title,body,commits 2>/dev/null || true
```

### 4. Check for any uncommitted changes or merge conflicts
```bash
git status
git diff --stat
```

If there are uncommitted changes, flag them clearly. If there are merge conflicts, surface them before anything else.

### 5. Understand who worked on what
Read the last few commit messages to understand what was built most recently:
```bash
git log --oneline -5
git log -1 --format="%an — %s%n%n%b"
```

### 6. Identify what's in progress vs. not started
Cross-reference the current branch's changes against `ROADMAP.md` to determine:
- What was the previous session working toward?
- Is that work complete or mid-flight?
- What's the logical next step?

---

## Briefing format

End with a concise briefing in this structure — keep it tight:

```
## Session Brief

**Branch:** <branch name>
**Last worked on:** <1-sentence summary of what the previous commit(s) built>
**Status:** <Complete / In progress — what's done and what isn't>

**Conflict risk:** <None / Low / High — any files likely to conflict with other in-flight PRs>

**Recommended next:** <The single most important thing to build this session, grounded in ROADMAP.md priority order>

**Watch out for:** <Any gotchas, half-finished state, or things to verify before writing new code>
```

Do not start building anything yet — present the brief and wait for the developer to confirm direction.

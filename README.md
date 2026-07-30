# 🧠 TeamBrain

Collective memory for the team. From today on, what each of us learns while
working with our agent (Copilot CLI, Claude Code, opencode) gets captured and
becomes available to everyone — without changing how you work.

## What it does (and does NOT do)

**Does:** when you close an agent session, a hook generates a *digest* — only
decisions, resolved bugs, and learnings — and pushes it to `raw/sessions/` in
the `teambrain` monorepo, signed with your git identity. If the session produced
nothing valuable, nothing is stored. If you're offline, it queues locally and
retries on your next session.

**Does NOT:** it does not upload full transcripts, your code, or your prompts.
The digest goes through automatic secret redaction before leaving your machine.
Everything sent is readable by you in `~/.teambrain/outbox` and in the repo.
Uninstall = `rm -rf ~/.teambrain`.

## Install (each dev, ~2 minutes)

```bash
gh repo clone aiudalabs/teambrain ~/.teambrain/repo
bash ~/.teambrain/repo/setup.sh
```

The installer detects which CLIs you have, installs the digest engine, adds the
Claude Code hook if applicable, and runs a test digest. You'll see ✓ per step.

**Copilot CLI is covered globally too:** the installer places user-level hooks
in `~/.copilot/hooks/`, which apply to all your sessions in any project. Repos
may also ship `.github/hooks/teambrain.json`; the digest engine dedupes so a
session is never captured twice.

## Staying in sync (pull)

Pushes are automatic (the sessionEnd hook). Pulls are too: a `sessionStart`
hook refreshes your local clone (`~/.teambrain/repo`) in the background every
time you open a session, so the team's knowledge is always current on your
machine. You can also pull manually anytime: `git -C ~/.teambrain/repo pull`.

## One-time setup (repo owner)

1. Create the `aiudalabs/teambrain` repo and run `bootstrap-repo.sh` inside it.
2. Grant *write* access to the team.
3. Commit into each product repo:
   - `.github/hooks/teambrain.json` ← `kit/copilot/teambrain.json`
   - `.claude/settings.json` ← `kit/claude/settings.json` (repos where Claude Code is used)
   - `.github/workflows/teambrain.yml` ← the 12-line caller (top of `.github/workflows/resumidor.yml`)
4. Org secrets: `COPILOT_CLI_TOKEN`, `TB_APP_ID`, `TB_APP_PRIVATE_KEY`.
5. Branch protection on `main` (require PR + CODEOWNERS review).

## What you'll notice

- Nothing, at first. You work exactly as before.
- Within days: `raw/sessions/` and `raw/github/` accumulating digests from the
  whole team, and the Librarian opening knowledge PRs against `wiki/`.
- Later (phase 2): your agents will consult this knowledge automatically before
  each task — "María already solved this last week" — via the AGENTS.md
  protocol and the teambrain MCP server.

## Repo layout

```
teambrain/
├── raw/          # immutable sources: session digests, PR/issue digests
├── wiki/         # curated knowledge (agents write here via PR only)
├── CLAUDE.md     # the schema — page types, frontmatter contract, rules
├── .teambrain/prompts/   # versioned agent prompts (Summarizer, Librarian)
├── .github/workflows/    # summarizer (reusable) + ingestor
├── .github/hooks/        # Copilot CLI sessionStart/sessionEnd hooks
└── kit/ + setup.sh       # per-dev installer
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `gh CLI not authenticated` | `gh auth login` |
| `could not clone teambrain` | Ask for write access to the repo |
| No digests appearing | Check `~/.teambrain/digest.log`; verify `jq` is installed |
| Digest stuck in outbox | Offline or no permissions — retries next session |

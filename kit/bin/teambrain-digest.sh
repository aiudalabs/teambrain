#!/usr/bin/env bash
# teambrain-digest.sh — captures the learnings of an agent session and pushes
# them to raw/sessions/ in the teambrain monorepo.
#
# Invoked by sessionEnd hooks (Copilot CLI and Claude Code). Receives the hook's
# JSON payload on stdin. Graceful degradation:
#   1) LLM digest via the dev's own CLI (copilot -p / claude -p)
#   2) no CLI or it fails → structured marker (repo, branch, diffstat)
#   3) no network → local queue in ~/.teambrain/outbox, retried later
#
# Philosophy: NEVER block or break the dev's session. When in doubt, fail
# silently and leave a trace in ~/.teambrain/digest.log.

set -u
TB_HOME="${TEAMBRAIN_HOME:-$HOME/.teambrain}"
TB_REPO="$TB_HOME/repo"
TB_OUTBOX="$TB_HOME/outbox"
TB_LOG="$TB_HOME/digest.log"
mkdir -p "$TB_OUTBOX" 2>/dev/null || exit 0

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >> "$TB_LOG" 2>/dev/null; }

# ---------- 1. Read hook payload (stdin JSON) ----------
PAYLOAD="$(cat 2>/dev/null || true)"
jqget() { printf '%s' "$PAYLOAD" | (command -v jq >/dev/null && jq -r "$1 // empty") 2>/dev/null; }
# No-jq fallback: basic regex extraction
rawget() { printf '%s' "$PAYLOAD" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1; }

SESSION_ID="$(jqget '.sessionId')"; [ -z "$SESSION_ID" ] && SESSION_ID="$(jqget '.session_id')"
[ -z "$SESSION_ID" ] && SESSION_ID="$(rawget sessionId)"; [ -z "$SESSION_ID" ] && SESSION_ID="$(rawget session_id)"
CWD="$(jqget '.cwd')"; [ -z "$CWD" ] && CWD="$(rawget cwd)"; [ -z "$CWD" ] && CWD="$PWD"
REASON="$(jqget '.reason')"; [ -z "$REASON" ] && REASON="$(rawget reason)"; [ -z "$REASON" ] && REASON="complete"
TRANSCRIPT="$(jqget '.transcript_path')"; [ -z "$TRANSCRIPT" ] && TRANSCRIPT="$(rawget transcript_path)"

# Aborted/timed-out sessions rarely leave reliable learnings
case "$REASON" in abort|timeout) log "skip reason=$REASON"; exit 0;; esac

# Dedupe guard: user-level AND repo-level hooks can both fire for the same
# session (Copilot CLI combines hook sources) — process each session once.
if [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "doctor-test" ]; then
  LAST="$TB_HOME/.last-session"
  [ -f "$LAST" ] && [ "$(cat "$LAST" 2>/dev/null)" = "$SESSION_ID" ] && { log "skip dup session=$SESSION_ID"; exit 0; }
  printf '%s' "$SESSION_ID" > "$LAST" 2>/dev/null || true
fi

# ---------- 2. Project git context ----------
cd "$CWD" 2>/dev/null || exit 0
REPO_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null || echo "$CWD")"
REPO_NAME="$(basename "$REPO_TOPLEVEL")"
BRANCH="$(git branch --show-current 2>/dev/null || echo '-')"
DEV="$(git config user.name 2>/dev/null || whoami)"
DIFFSTAT="$(git diff --stat HEAD 2>/dev/null | tail -5)"
STAMP="$(date -u +%Y-%m-%d)"; TS="$(date -u +%H%M%S)"

# ---------- 2.5 Confidentiality gate: DEFAULT-DENY allowlist ----------
# Only repos explicitly enrolled in teambrain/.teambrain/tracked-repos.txt are
# captured. Confidential projects are never tracked unless added via PR.
if [ "$REPO_TOPLEVEL" != "$TB_REPO" ]; then
  ALLOW="$TB_REPO/.teambrain/tracked-repos.txt"
  REMOTE="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@|https://)([^/:]+)[:/]##; s#\.git$##')"
  MATCHED=0
  if [ -f "$ALLOW" ]; then
    while IFS= read -r line; do
      line="${line%%#*}"; line="$(printf '%s' "$line" | tr -d '[:space:]')"
      [ -z "$line" ] && continue
      if [ "$line" = "$REPO_NAME" ] || [ "$line" = "$REMOTE" ]; then MATCHED=1; break; fi
    done < "$ALLOW"
  fi
  [ "$MATCHED" -eq 1 ] || { log "skip untracked repo=$REPO_NAME"; exit 0; }
fi

# ---------- 3. Generate the digest ----------
PROMPT='You just finished a work session in this repository. Summarize ONLY the durable knowledge a teammate should inherit, in markdown, in English:
## Decisions (what was decided and why)
## Resolved bugs (symptom → cause → fix)
## Learnings (non-obvious things discovered)
Rules: max 25 lines; no long code; no secrets, tokens or credentials; if the session produced NOTHING in these categories (formatting only, trivial exploration), respond exactly: SKIP'

DIGEST=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] && command -v claude >/dev/null 2>&1; then
  # Claude Code: we have the transcript — highest quality digest
  DIGEST="$(tail -c 200000 "$TRANSCRIPT" | claude -p "$PROMPT (based on the transcript on stdin)" 2>/dev/null)"
elif command -v copilot >/dev/null 2>&1 && [ -n "$SESSION_ID" ]; then
  # Copilot CLI: try summarizing by resuming the session in programmatic mode
  DIGEST="$(copilot --resume "$SESSION_ID" -p "$PROMPT" --allow-tool 'shell(git log)' 2>/dev/null)"
fi

# Fallback: structured marker (always works, zero dependencies)
if [ -z "$DIGEST" ]; then
  DIGEST="_(automatic marker — no LLM digest available)_

Files touched:
\`\`\`
${DIFFSTAT:-"(no uncommitted changes)"}
\`\`\`"
fi

# Worthless session → don't pollute raw/
printf '%s' "$DIGEST" | grep -qx 'SKIP' && { log "skip no-value repo=$REPO_NAME"; exit 0; }

# ---------- 4. Basic secret redaction ----------
DIGEST="$(printf '%s' "$DIGEST" | sed -E \
  -e 's/(gh[pousr]_[A-Za-z0-9]{20,})/[REDACTED]/g' \
  -e 's/(AKIA[A-Z0-9]{12,})/[REDACTED]/g' \
  -e 's/(sk-[A-Za-z0-9_-]{20,})/[REDACTED]/g' \
  -e 's/(-----BEGIN [A-Z ]+PRIVATE KEY-----)/[REDACTED]/g' \
  -e 's/((api[_-]?key|token|password|secret)[[:space:]]*[=:][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig')"

# ---------- 5. Write the digest file ----------
FNAME="${STAMP}-$(echo "$DEV" | tr 'A-Z ' 'a-z-')-${REPO_NAME}-${TS}.md"
TMP="$TB_OUTBOX/$FNAME"
cat > "$TMP" <<EOF
---
type: session-digest
dev: $DEV
repo: $REPO_NAME
branch: $BRANCH
date: ${STAMP}T${TS}Z
session: ${SESSION_ID:-manual}
close_reason: $REASON
---

$DIGEST
EOF

# ---------- 6. Push to teambrain (outbox as safety net) ----------
push_outbox() {
  [ -d "$TB_REPO/.git" ] || { log "teambrain repo not cloned; kept in outbox"; return 1; }
  cd "$TB_REPO" || return 1
  git pull --rebase --quiet origin main 2>/dev/null || return 1
  mkdir -p raw/sessions
  local n=0
  for f in "$TB_OUTBOX"/*.md; do
    [ -e "$f" ] || break
    mv "$f" "raw/sessions/$(basename "$f")" && n=$((n+1))
  done
  [ "$n" -eq 0 ] && return 0
  git add raw/sessions && \
  git commit --quiet -m "digest: $n session(s) from $DEV" 2>/dev/null && \
  git push --quiet origin main 2>/dev/null || return 1
  log "push ok ($n digests)"
}

# Run in background so the dev's session close isn't delayed
( push_outbox || log "push failed; $(ls "$TB_OUTBOX" | wc -l | tr -d ' ') pending in outbox" ) >/dev/null 2>&1 &
disown 2>/dev/null || true
exit 0

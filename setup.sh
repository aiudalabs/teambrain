#!/usr/bin/env bash
# TeamBrain — per-dev installer (2 minutes, once)
# Usage:  gh repo clone aiudalabs/teambrain ~/.teambrain/repo && bash ~/.teambrain/repo/setup.sh
set -e
TB_HOME="${TEAMBRAIN_HOME:-$HOME/.teambrain}"
TB_REPO="$TB_HOME/repo"
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; N='\033[0m'
ok(){ printf "${G}  ✓ %s${N}\n" "$1"; }
warn(){ printf "${Y}  ⚠ %s${N}\n" "$1"; }
fail(){ printf "${R}  ✗ %s${N}\n" "$1"; FAILED=1; }
FAILED=0

echo ""
echo "🧠 TeamBrain — install"
echo "──────────────────────"

# ---------- Prerequisites ----------
command -v git >/dev/null && ok "git" || fail "git not found"
command -v jq  >/dev/null && ok "jq"  || warn "jq not found (recommended: brew/apt install jq)"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  ok "gh authenticated as $(gh api user --jq .login 2>/dev/null)"
else
  fail "gh CLI not authenticated — run: gh auth login"
fi

HARNESS=0
command -v copilot >/dev/null && { ok "Copilot CLI detected"; HARNESS=1; }
command -v claude  >/dev/null && { ok "Claude Code detected"; HARNESS=1; }
command -v opencode >/dev/null && { ok "opencode detected (capture via AGENTS.md protocol)"; HARNESS=1; }
[ "$HARNESS" -eq 0 ] && warn "no agent CLI detected — digests will use the structured marker"

GIT_NAME="$(git config --global user.name || true)"
[ -n "$GIT_NAME" ] && ok "git identity: $GIT_NAME" || fail "set your identity: git config --global user.name/email"

[ "$FAILED" -eq 1 ] && { echo ""; echo "Fix the items marked ✗ and run again."; exit 1; }

# ---------- Install ----------
mkdir -p "$TB_HOME/bin" "$TB_HOME/outbox"
cp "$KIT_DIR/kit/bin/teambrain-digest.sh" "$TB_HOME/bin/teambrain-digest.sh"
chmod +x "$TB_HOME/bin/teambrain-digest.sh"
ok "digest engine installed in ~/.teambrain/bin"

if [ ! -d "$TB_REPO/.git" ]; then
  gh repo clone "${TEAMBRAIN_ORG:-aiudalabs}/teambrain" "$TB_REPO" -- --quiet 2>/dev/null \
    && ok "teambrain monorepo cloned" \
    || fail "could not clone ${TEAMBRAIN_ORG:-aiudalabs}/teambrain — do you have write access?"
else
  ok "teambrain monorepo already cloned"
fi

# Global Claude Code hook (product repos ship their own committed copy;
# this covers repos that don't have it yet)
if command -v claude >/dev/null; then
  CS="$HOME/.claude/settings.json"; mkdir -p "$HOME/.claude"
  if [ -f "$CS" ] && command -v jq >/dev/null; then
    if ! grep -q teambrain-digest "$CS" 2>/dev/null; then
      jq -s '.[0] * .[1]' "$CS" "$KIT_DIR/kit/claude/settings.json" > "$CS.tmp" && mv "$CS.tmp" "$CS" \
        && ok "SessionStart/SessionEnd hooks added to ~/.claude/settings.json" \
        || warn "could not merge ~/.claude/settings.json — add the hook manually (kit/claude/settings.json)"
    else ok "Claude Code hook already present"; fi
  else
    jq 'del(.["$comment"])' "$KIT_DIR/kit/claude/settings.json" > "$CS" 2>/dev/null || cp "$KIT_DIR/kit/claude/settings.json" "$CS"
    ok "hooks created in ~/.claude/settings.json"
  fi
fi
# Copilot CLI: user-level hooks → apply to ALL sessions in ANY project
if command -v copilot >/dev/null; then
  mkdir -p "$HOME/.copilot/hooks"
  cp "$KIT_DIR/kit/copilot/teambrain.json" "$HOME/.copilot/hooks/teambrain.json"
  ok "Copilot CLI user-level hooks installed (~/.copilot/hooks) — all projects covered"
fi
# Repo-level hooks (.github/hooks/teambrain.json) remain as harmless belt-and-suspenders.

# ---------- Doctor ----------
echo ""
echo "Doctor:"
cd "$TB_REPO" 2>/dev/null && git push --dry-run --quiet origin main 2>/dev/null \
  && ok "write access to teambrain verified" \
  || warn "could not verify push to teambrain (repo permissions?)"
echo '{"cwd":"'"$TB_REPO"'","reason":"complete","sessionId":"doctor-test"}' \
  | "$TB_HOME/bin/teambrain-digest.sh" && ok "test digest executed (check raw/sessions/ in a few seconds)"

echo ""
printf "${G}Done. Work as usual — TeamBrain learns on its own.${N}\n"
echo "Local log: ~/.teambrain/digest.log · Uninstall: rm -rf ~/.teambrain"

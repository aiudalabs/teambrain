#!/usr/bin/env bash
# TeamBrain — instalador por dev (2 minutos, una sola vez)
# Uso:  gh repo clone aiuda/teambrain ~/.teambrain/repo && bash ~/.teambrain/repo/kit/../setup.sh
#   (o) bash setup.sh   desde el clon del monorepo teambrain
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
echo "🧠 TeamBrain — instalación"
echo "──────────────────────────"

# ---------- Prerequisitos ----------
command -v git >/dev/null && ok "git" || fail "git no encontrado"
command -v jq  >/dev/null && ok "jq"  || warn "jq no encontrado (recomendado: brew/apt install jq)"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  ok "gh autenticado como $(gh api user --jq .login 2>/dev/null)"
else
  fail "gh CLI no autenticado — corre: gh auth login"
fi

HARNESS=0
command -v copilot >/dev/null && { ok "Copilot CLI detectado"; HARNESS=1; }
command -v claude  >/dev/null && { ok "Claude Code detectado"; HARNESS=1; }
command -v opencode >/dev/null && { ok "opencode detectado (captura vía protocolo AGENTS.md)"; HARNESS=1; }
[ "$HARNESS" -eq 0 ] && warn "ningún CLI de agente detectado — el digest usará el marcador estructurado"

GIT_NAME="$(git config --global user.name || true)"
[ -n "$GIT_NAME" ] && ok "identidad git: $GIT_NAME" || fail "configura tu identidad: git config --global user.name/email"

[ "$FAILED" -eq 1 ] && { echo ""; echo "Corrige lo marcado con ✗ y vuelve a correr."; exit 1; }

# ---------- Instalar ----------
mkdir -p "$TB_HOME/bin" "$TB_HOME/outbox"
cp "$KIT_DIR/kit/bin/teambrain-digest.sh" "$TB_HOME/bin/teambrain-digest.sh"
chmod +x "$TB_HOME/bin/teambrain-digest.sh"
ok "motor de digest instalado en ~/.teambrain/bin"

if [ ! -d "$TB_REPO/.git" ]; then
  gh repo clone "${TEAMBRAIN_ORG:-aiuda}/teambrain" "$TB_REPO" -- --quiet 2>/dev/null \
    && ok "monorepo teambrain clonado" \
    || fail "no pude clonar ${TEAMBRAIN_ORG:-aiuda}/teambrain — ¿tienes acceso write?"
else
  ok "monorepo teambrain ya clonado"
fi

# Hook global de Claude Code (los repos de producto traen el suyo committeado;
# esto cubre repos que aún no lo tengan)
if command -v claude >/dev/null; then
  CS="$HOME/.claude/settings.json"; mkdir -p "$HOME/.claude"
  if [ -f "$CS" ] && command -v jq >/dev/null; then
    if ! grep -q teambrain-digest "$CS" 2>/dev/null; then
      jq -s '.[0] * .[1]' "$CS" "$KIT_DIR/kit/claude/settings.json" > "$CS.tmp" && mv "$CS.tmp" "$CS" \
        && ok "hook SessionEnd agregado a ~/.claude/settings.json" \
        || warn "no pude mergear ~/.claude/settings.json — agrega el hook a mano (kit/claude/settings.json)"
    else ok "hook de Claude Code ya presente"; fi
  else
    jq 'del(.["$comment"])' "$KIT_DIR/kit/claude/settings.json" > "$CS" 2>/dev/null || cp "$KIT_DIR/kit/claude/settings.json" "$CS"
    ok "hook SessionEnd creado en ~/.claude/settings.json"
  fi
fi
# Copilot CLI: el hook viaja en cada repo (.github/hooks/teambrain.json) — nada que instalar aquí.

# ---------- Doctor ----------
echo ""
echo "Doctor:"
cd "$TB_REPO" 2>/dev/null && git push --dry-run --quiet origin main 2>/dev/null \
  && ok "acceso de escritura a teambrain verificado" \
  || warn "no pude verificar push a teambrain (¿permisos del repo?)"
echo '{"cwd":"'"$TB_REPO"'","reason":"complete","sessionId":"doctor-test"}' \
  | "$TB_HOME/bin/teambrain-digest.sh" && ok "digest de prueba ejecutado (mira raw/sessions/ en unos segundos)"

echo ""
printf "${G}Listo. Trabaja normal — TeamBrain aprende solo.${N}\n"
echo "Log local: ~/.teambrain/digest.log · Para desinstalar: rm -rf ~/.teambrain"

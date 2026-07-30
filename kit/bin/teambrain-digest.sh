#!/usr/bin/env bash
# teambrain-digest.sh — captura el aprendizaje de una sesión de agente y lo
# empuja a raw/sessions/ del monorepo teambrain.
#
# Invocado por hooks de sessionEnd (Copilot CLI y Claude Code). Recibe el
# payload JSON del hook por stdin. Degradación elegante:
#   1) digest LLM vía el CLI del propio dev (copilot -p / claude -p)
#   2) si no hay CLI o falla → marcador estructurado (repo, branch, diffstat)
#   3) si no hay red → cola local en ~/.teambrain/outbox, se reintenta luego
#
# Filosofía: NUNCA bloquear ni romper la sesión del dev. Ante cualquier duda,
# fallar en silencio y dejar rastro en ~/.teambrain/digest.log.

set -u
TB_HOME="${TEAMBRAIN_HOME:-$HOME/.teambrain}"
TB_REPO="$TB_HOME/repo"
TB_OUTBOX="$TB_HOME/outbox"
TB_LOG="$TB_HOME/digest.log"
mkdir -p "$TB_OUTBOX" 2>/dev/null || exit 0

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >> "$TB_LOG" 2>/dev/null; }

# ---------- 1. Leer payload del hook (stdin JSON) ----------
PAYLOAD="$(cat 2>/dev/null || true)"
jqget() { printf '%s' "$PAYLOAD" | (command -v jq >/dev/null && jq -r "$1 // empty") 2>/dev/null; }
# Fallback sin jq: extracción básica por regex
rawget() { printf '%s' "$PAYLOAD" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1; }

SESSION_ID="$(jqget '.sessionId')"; [ -z "$SESSION_ID" ] && SESSION_ID="$(jqget '.session_id')"
[ -z "$SESSION_ID" ] && SESSION_ID="$(rawget sessionId)"; [ -z "$SESSION_ID" ] && SESSION_ID="$(rawget session_id)"
CWD="$(jqget '.cwd')"; [ -z "$CWD" ] && CWD="$(rawget cwd)"; [ -z "$CWD" ] && CWD="$PWD"
REASON="$(jqget '.reason')"; [ -z "$REASON" ] && REASON="$(rawget reason)"; [ -z "$REASON" ] && REASON="complete"
TRANSCRIPT="$(jqget '.transcript_path')"; [ -z "$TRANSCRIPT" ] && TRANSCRIPT="$(rawget transcript_path)"

# Sesiones abortadas o con error no suelen dejar aprendizaje confiable
case "$REASON" in abort|timeout) log "skip reason=$REASON"; exit 0;; esac

# ---------- 2. Contexto git del proyecto ----------
cd "$CWD" 2>/dev/null || exit 0
REPO_NAME="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$CWD")")"
BRANCH="$(git branch --show-current 2>/dev/null || echo '-')"
DEV="$(git config user.name 2>/dev/null || whoami)"
DIFFSTAT="$(git diff --stat HEAD 2>/dev/null | tail -5)"
STAMP="$(date -u +%Y-%m-%d)"; TS="$(date -u +%H%M%S)"

# ---------- 3. Generar el digest ----------
PROMPT='Acabas de terminar una sesión de trabajo en este repositorio. Resume SOLO el conocimiento durable que un compañero de equipo debería heredar, en markdown y en español:
## Decisiones (qué se decidió y por qué)
## Bugs resueltos (síntoma → causa → fix)
## Aprendizajes (cosas no-obvias descubiertas)
Reglas: máximo 25 líneas; sin código extenso; sin secretos, tokens ni credenciales; si la sesión NO produjo nada de estas categorías (solo formateo, exploración trivial), responde exactamente: SKIP'

DIGEST=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] && command -v claude >/dev/null 2>&1; then
  # Claude Code: tenemos el transcript — digest de máxima calidad
  DIGEST="$(tail -c 200000 "$TRANSCRIPT" | claude -p "$PROMPT (basado en el transcript en stdin)" 2>/dev/null)"
elif command -v copilot >/dev/null 2>&1 && [ -n "$SESSION_ID" ]; then
  # Copilot CLI: intentar resumir reanudando la sesión en modo programático
  DIGEST="$(copilot --resume "$SESSION_ID" -p "$PROMPT" --allow-tool 'shell(git log)' 2>/dev/null)"
fi

# Fallback: marcador estructurado (siempre funciona, cero dependencias)
if [ -z "$DIGEST" ]; then
  DIGEST="_(marcador automático — sin digest LLM disponible)_

Archivos tocados:
\`\`\`
${DIFFSTAT:-"(sin cambios sin commitear)"}
\`\`\`"
fi

# Sesión sin valor → no ensuciar raw/
printf '%s' "$DIGEST" | grep -qx 'SKIP' && { log "skip sin-valor repo=$REPO_NAME"; exit 0; }

# ---------- 4. Redacción básica de secretos ----------
DIGEST="$(printf '%s' "$DIGEST" | sed -E \
  -e 's/(gh[pousr]_[A-Za-z0-9]{20,})/[REDACTADO]/g' \
  -e 's/(AKIA[A-Z0-9]{12,})/[REDACTADO]/g' \
  -e 's/(sk-[A-Za-z0-9_-]{20,})/[REDACTADO]/g' \
  -e 's/(-----BEGIN [A-Z ]+PRIVATE KEY-----)/[REDACTADO]/g' \
  -e 's/((api[_-]?key|token|password|secret)[[:space:]]*[=:][[:space:]]*)[^[:space:]]+/\1[REDACTADO]/Ig')"

# ---------- 5. Escribir el archivo de digest ----------
FNAME="${STAMP}-$(echo "$DEV" | tr 'A-Z ' 'a-z-')-${REPO_NAME}-${TS}.md"
TMP="$TB_OUTBOX/$FNAME"
cat > "$TMP" <<EOF
---
tipo: session-digest
dev: $DEV
repo: $REPO_NAME
branch: $BRANCH
fecha: ${STAMP}T${TS}Z
sesion: ${SESSION_ID:-manual}
motivo_cierre: $REASON
---

$DIGEST
EOF

# ---------- 6. Push a teambrain (con outbox como red de seguridad) ----------
push_outbox() {
  [ -d "$TB_REPO/.git" ] || { log "repo teambrain no clonado; queda en outbox"; return 1; }
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
  git commit --quiet -m "digest: $n sesión(es) de $DEV" 2>/dev/null && \
  git push --quiet origin main 2>/dev/null || return 1
  log "push ok ($n digests)"
}

# En background para no retrasar el cierre de la sesión del dev
( push_outbox || log "push falló; $(ls "$TB_OUTBOX" | wc -l | tr -d ' ') pendientes en outbox" ) >/dev/null 2>&1 &
disown 2>/dev/null || true
exit 0

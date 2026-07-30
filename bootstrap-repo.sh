#!/usr/bin/env bash
# TeamBrain — bootstrap del monorepo (lo corre Noel UNA vez, dentro del repo teambrain recién creado)
set -e
mkdir -p raw/sessions raw/github raw/meetings raw/docs
mkdir -p wiki/concepts wiki/projects wiki/contradictions wiki/people
mkdir -p .teambrain/workflows .github/hooks

touch raw/sessions/.gitkeep raw/github/.gitkeep wiki/concepts/.gitkeep wiki/projects/.gitkeep

[ -f index.md ] || cat > index.md <<'EOF'
# TeamBrain — índice
_(regenerado por el indexer; vacío hasta la primera ingesta)_
EOF

[ -f log.md ] || printf '# Bitácora de operaciones\n\n' > log.md

[ -f CLAUDE.md ] || cat > CLAUDE.md <<'EOF'
# TeamBrain — Schema (v0)

Wiki de conocimiento del equipo. Reglas para todo agente que escriba aquí:

## Tipos de página (frontmatter `type`)
playbook · decision (exige rationale + reversal_condition) · postmortem ·
synthesis · entity · reference (exige review_by) · contradiction (solo el linter las crea)

## Frontmatter obligatorio
id, type, project, status, confidence, sources (rutas a raw/), contributors,
created, updated, review_by, links

## Reglas
- raw/ es inmutable y append-only. wiki/ solo se toca vía PR.
- Comprimir, no espejar: una página existe solo si sintetiza ≥2 fuentes o
  conocimiento no-greppeable. Máx ~600 palabras.
- Toda página enlaza y es enlazada ([[wikilinks]]).
- Toda afirmación es trazable a una fuente en raw/.
EOF

[ -f CODEOWNERS ] || cat > CODEOWNERS <<'EOF'
# Ajustar con los miembros reales de cada proyecto
/wiki/concepts/   @noel
/CLAUDE.md        @noel
# /wiki/projects/proyecto-a/  @dev1 @dev2 @noel
# /wiki/projects/proyecto-b/  @dev3 @dev4 @dev5
EOF

echo "✓ Estructura creada. Siguiente:"
echo "  1. git add -A && git commit -m 'bootstrap teambrain' && git push"
echo "  2. Dar acceso write al equipo (Settings → Collaborators/Teams)"
echo "  3. En CADA repo de producto, commitear:"
echo "       .github/hooks/teambrain.json      (kit/copilot/teambrain.json)"
echo "       .claude/settings.json             (kit/claude/settings.json, si usan Claude Code)"

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

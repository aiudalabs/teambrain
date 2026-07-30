# TeamBrain — Schema (v0)

Team knowledge wiki. Rules for every agent that writes here:

## Page types (frontmatter `type`)
playbook · decision (requires rationale + reversal_condition) · postmortem ·
synthesis · entity · reference (requires review_by) · contradiction (only the linter creates these)

## Required frontmatter
id, type, project, status, confidence, sources (paths into raw/), contributors,
created, updated, review_by, links, tags (must mirror `type`, e.g. `tags: [playbook]` —
powers color groups in Obsidian's graph view)

## Rules
- raw/ is immutable and append-only. wiki/ is only ever modified via PR.
- Compress, don't mirror: a page exists only if it synthesizes ≥2 sources or
  captures non-greppable knowledge. Max ~600 words.
- Every page links and is linked ([[wikilinks]]).
- Every claim is traceable to a source in raw/.

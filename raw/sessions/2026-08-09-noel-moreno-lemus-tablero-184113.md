---
tipo: session-digest
dev: Noel Moreno Lemus
repo: tablero
branch: main
fecha: 2026-08-09T184113Z
sesion: 649deb93-cde9-4f11-91b4-f1f211772a01
motivo_cierre: other
---

## Decisiones (qué se decidió y por qué)
- Estructura de 4 epics para el Tablero, aprobada headless y guardada en `_bmad-output/planning-artifacts/epics.md` (frontmatter `stepsCompleted: [1, 2]`):
  - Epic 1 "Ver los runs en vivo" (FR-1, FR-2) como **walking skeleton**: scaffold, Server BFF con whitelist/envelope, labels y polling nacen acá; absorbe NFR-1/2/3/5.
  - Epic 2 "Seguir el sprint y el orquestador" (FR-3–FR-6, UJ-1); Epic 3 "Desbloquear, orquestar y cerrar" (FR-7–FR-12, UJ-2/UJ-3, incluye el smoke de spawn detached sin TTY); Epic 4 "Apuntar a cualquier proyecto" (FR-13/FR-14).
- Dependencias: Epics 2–4 solo dependen del 1; ninguno requiere uno futuro. `project` como parámetro de request (AD-6) se implementa desde Epic 1 aunque el selector de UI llega en Epic 4.
- No hay documento UX separado: el contrato de presentación queda absorbido por las Consistency Conventions del spine (labels solo en `src/labels/`, CSS plano, navegación por hash, tie-breaker "simple e interactivo > completo") — decisión registrada en el epics.md.
- Los NFRs se mapearon como transversales (no como stories propias): NFR-1/2/3 son infraestructura del Epic 1; NFR-4 aplica a cada lectura de artefactos; NFR-5 a toda story de UI.

## Bugs resueltos (síntoma → causa → fix)
- Ninguno (sesión de planificación, sin código ejecutado).

## Aprendizajes (cosas no-obvias descubiertas)
- **La sesión quedó interrumpida a mitad del Step 3** (crear stories): epics.md tiene requirements inventory, FR coverage map y epic list, pero **cero stories**. El próximo run de `/bmad-create-epics-and-stories` debe retomar desde step-03 leyendo el frontmatter, no rehacer los pasos 1–2.
- El inventario de "Additional Requirements" del epics.md ya condensa todos los ADs del spine (AD-1…AD-13, rutas API, contrato del tail del journal, stack pineado) — es la fuente autocontenida para escribir stories sin releer el spine completo.
- Contexto verificado en runs previos y reutilizado acá: `tokens.weighted` existe en `status --json`; Gate vs Escalación se deriva de `paused_stage`; sweeps comparten `status --json`; CLI ~110 ms/invocación → sin caché.
- El hook de SessionEnd `teambrain-digest.sh` viene fallando con "Hook cancelled" en los runs headless de este repo (aparece en los logs de PRD y arquitectura) — los digests de esas sesiones pueden no haberse persistido.

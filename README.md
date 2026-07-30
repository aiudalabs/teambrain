# 🧠 TeamBrain — Kit de instalación

Memoria colectiva del equipo. A partir de hoy, lo que cada uno aprende trabajando
con su agente (Copilot CLI, Claude Code, opencode) queda registrado y disponible
para todos — sin cambiar tu forma de trabajar.

## Qué hace (y qué NO hace)

**Hace:** al cerrar cada sesión de tu agente, un hook genera un *digest* — solo
decisiones, bugs resueltos y aprendizajes — y lo empuja a `raw/sessions/` del
monorepo `teambrain`, firmado con tu identidad git. Si la sesión no produjo nada
valioso, no se guarda nada. Si no hay red, queda en cola local y se envía después.

**NO hace:** no sube transcripts completos, no sube tu código, no registra tus
prompts. El digest pasa por redacción automática de secretos antes de salir de tu
máquina. Todo lo que se envía es legible por ti en `~/.teambrain/outbox` y en el
repo. Desinstalar = `rm -rf ~/.teambrain`.

## Instalación (cada dev, ~2 minutos)

```bash
gh repo clone aiuda/teambrain ~/.teambrain/repo
bash ~/.teambrain/repo/setup.sh
```

El instalador detecta qué CLIs tienes, instala el motor de digest, agrega el hook
de Claude Code si aplica, y corre un digest de prueba. Verás ✓ en cada paso.

**Copilot CLI no necesita nada extra:** el hook viaja committeado en cada repo de
producto (`.github/hooks/teambrain.json`) y se activa solo al confirmar la
confianza de la carpeta la primera vez que abras `copilot` ahí.

## Preparación previa (Noel, una vez)

1. Crear el repo `aiuda/teambrain` y correr `bootstrap-repo.sh` dentro.
2. Dar acceso *write* al equipo.
3. Commitear en cada repo de producto:
   - `.github/hooks/teambrain.json` ← `kit/copilot/teambrain.json`
   - `.claude/settings.json` ← `kit/claude/settings.json` (repos donde se use Claude Code)

## Qué van a notar

- Nada, al principio. Trabajan igual que siempre.
- En unos días: `raw/sessions/` acumulando digests de todo el equipo.
- Después (fase 2): sus agentes consultarán ese conocimiento automáticamente
  antes de cada tarea — "esto ya lo resolvió María la semana pasada" — vía el
  protocolo en AGENTS.md y el MCP server de teambrain.

## Problemas comunes

| Síntoma | Fix |
|---|---|
| `gh CLI no autenticado` | `gh auth login` |
| `no pude clonar teambrain` | Pedir acceso write al repo |
| No aparecen digests | Revisar `~/.teambrain/digest.log`; verificar `jq` instalado |
| Digest quedó en outbox | Sin red o sin permisos — se reintenta en la próxima sesión |

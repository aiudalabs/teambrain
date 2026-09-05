---
tipo: session-digest
dev: Noel Moreno Lemus
repo: workspace
branch: -
fecha: 2026-09-05T231003Z
sesion: 60dce1e0-0fa5-4567-af5f-8fc98debcebf
motivo_cierre: other
---

## Decisiones
- Cada bloque de stack trace en `log.stack` se delimita por una línea que contiene solo un número (ID/offset), seguida de líneas con frames indentadas por tab que empiezan con `in `.
- Un "call site" único se define como la tupla de los primeros 3 frames de cada bloque (después de descartar la línea `printStack()`, que es idéntica en todos los bloques y no aporta información).

## Bugs resueltos
- N/A — la sesión fue de exploración/parseo, no se corrigió ningún bug de código.

## Aprendizajes
- El archivo tiene 26715 líneas totales, 631 bloques (headers numéricos) y el frame1 es idéntico en el 100% de los bloques (`printStack() ... CallProfiling.cpp:322:3`), por lo que no sirve para diferenciar call sites — hay que mirar desde el frame2 en adelante.
- Existen 8 líneas "malformadas" que no siguen el patrón `\tin ...` (fragmentos de rutas truncadas, ej. líneas que empiezan directo con texto de ruta sin el prefijo `in`), hay que tolerarlas al parsear en vez de asumir formato estricto siempre.
- El zip trae basura de macOS (`__MACOSX/._log.stack`) que se puede ignorar al descomprimir.

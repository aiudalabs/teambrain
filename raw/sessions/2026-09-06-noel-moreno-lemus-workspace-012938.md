---
tipo: session-digest
dev: Noel Moreno Lemus
repo: workspace
branch: -
fecha: 2026-09-06T012938Z
sesion: 8fad4565-ec90-42ff-8c3e-1e70e2602921
motivo_cierre: other
---

## Bugs resueltos (síntoma → causa → fix)
- CBC (PuLP) reportó "Optimal" con gap del 3% tras agotar el time limit de 300s → CBC etiqueta como "Optimal" incluso al detenerse por límite de tiempo cuando aún hay gap abierto; no basta con leer el status. Fix: verificar explícitamente el gap/lower bound reportado, no confiar en el string "Optimal" del status.
- Monitor de proceso en background dio falso positivo de finalización → el polling inicial fue insuficiente para distinguir el proceso hijo real (cbc) del wrapper de shell/python; hubo que identificar el PID real vía `ps aux` y armar un Monitor sobre ese PID específico.
- HiGHS (highspy) terminó con exit code 137 (OOM/kill) tras ~3.3s de branch & bound en un problema de solo 63x63 → probablemente por symmetry detection agresiva o memoria del proceso embebido en Python; no se llegó a solución con HiGHS en esta sesión.

## Aprendizajes (cosas no-obvias descubiertas)
- El problema (question.mps, 63 filas/63 columnas, 53 binarias + 10 continuas) es difícil para B&B pese a su tamaño pequeño: CBC exploró >1.3M nodos en 300s sin cerrar el gap (mejor solución 15, cota inferior 14.5).
- Antes de aceptar un "Optimal" con gap>0 hay que chequear si el objetivo es forzosamente entero: en este modelo, las 10 variables continuas con coeficiente no-cero en el objetivo (d54–d63) impiden asumir integralidad automática, así que un gap fraccionario no se puede descartar por redondeo.
- HiGHS vía `highspy` está disponible en el entorno (via pip) como alternativa a CBC, pero en este caso murió por OOM/kill (exit 137) — no es un reemplazo drop-in confiable aquí sin ajustar límites de memoria/hilos.

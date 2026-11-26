---
tipo: session-digest
dev: Noel Moreno Lemus
repo: work
branch: -
fecha: 2026-11-26T233714Z
sesion: 4c81877e-3f34-43e1-b6df-47cd6ce80c79
motivo_cierre: other
---

## Decisiones
- Corrida biz-eda sobre `media_campaigns_sample.csv` (200 filas), dominio `media`, en `.eda_workspace/20261126_120000_media_campaigns/`.
- Contexto de negocio: reasignar presupuesto entre canales, con CPA como KPI principal y `media_spend` como columna de valor.
- Supuestos sin confirmar por negocio: CPA = suma de `media_spend` / suma de `conversions`, y grano `report_date` + `channel` + `campaign_id`. La moneda y la ventana de atribución siguen pendientes.

## Bugs resueltos
- Ninguno.

## Aprendizajes
- `ctr` viene en escala porcentual (0..100), aunque el concepto del dominio es un ratio 0..1. Además, 3 valores superan 100, algo que conviene investigar.
- `unique_reach`, `ctr` y `cpm` no son aditivos. `ctr` y `cpm` se recalculan desde los totales.
- `conversions` solo es aditiva dentro de la misma plataforma y ventana de atribución. Sumarla entre canales puede contar doble y afecta la comparación de CPA.
- `BIZ_EDA_PREAPPROVED_CERTIFIER` estaba vacía, así que el agente no puede certificar. `profile` requiere certificación humana o `--allow-draft`, este último solo si la solicitud acepta una corrida DRAFT.
- Con `.eda_workspace/` presente, el hook de protección bloquea `python`, los bucles y la impresión de filas del dataset. Se usa el lanzador `bin/biz-eda` y `slice` para consultar datos.
- Estado al cierre del transcript: metadata y perfil semántico en borrador. Aún no se había ejecutado `profile` ni generado el memo.

---
tipo: session-digest
dev: Noel Moreno Lemus
repo: libro-es
branch: master
fecha: 2026-09-04T024317Z
sesion: 7121a95b-1c04-49c6-a011-e8168cb6d220
motivo_cierre: other
---

## Revisión del PR — `src/billing/discounts.py`, `tests/billing/test_discounts.py`

**Veredicto: Aprobar con un comentario a resolver (no bloqueante para merge, pero vale la pena discutirlo).**

### Lo que hace bien el diff
- `apply()`: el piso en cero (`discount.amount > cart.total` → `cart.total = 0`) es correcto y está cubierto por el nuevo test `test_apply_discount_larger_than_total_floors_at_zero`. Ambas ramas (`if`/`else`) llegan al `cart.applied_codes.append(code)`, así que el registro de código aplicado no se pierde en el caso de piso.

### Hallazgo nuevo (no es el mismo tema que SEC-119 / BILL-482)
`bulk_apply()` ahora puede dejar `cart.applied_codes` **inconsistente con `cart.total`**, algo que no ocurría antes de este diff:

- Antes: sin el bloque de dedup, `applied_codes` tenía una entrada por cada aplicación real — inexacto en cantidad de códigos únicos, pero fiel a lo que efectivamente se cobró.
- Ahora: el `pop()` borra la entrada duplicada de la lista, pero **no revierte el descuento en `cart.total`**. Con `codes = ["A", "A"]` y `amount=10`, `total` queda descontado dos veces pero `applied_codes == ["A"]`.

Esto convierte `applied_codes` en un registro que ya no refleja lo cobrado — relevante en facturación para reconciliación/soporte a reembolsos. Es un problema distinto al ya aceptado (que era sobre el doble cobro en sí); aquí el riesgo es que el "fix" parcial genera una falsa sensación de corrección en el tracking mientras el monto sigue mal.

**Sugerencia**: hasta que BILL-482 resuelva la causa raíz, sería más seguro no tocar `applied_codes` en `bulk_apply` (dejarlo fiel a la realidad, aunque tenga duplicados) en vez de "limpiarlo" a medias. Si el equipo prefiere mantenerlo como está por ser código ya aceptado como riesgo teórico, al menos vale dejarlo anotado junto a SEC-119 ya que amplía su alcance (ahora afecta también a la integridad del dato, no solo al monto).

No repito las dos quejas ya aceptadas (SEC-119, BILL-482) porque el diff no las contradice — solo señalo que este cambio específico les agrega una arista nueva.

# RetailPro — Pre-entrega 4: Consultas SQL de negocio

Agregaciones sobre la base de RetailPro (`COUNT`, `SUM`, `AVG`, `GROUP BY`, `HAVING`, `CASE WHEN`). Cuarta pieza del proyecto integrador: el Módulo 1 definió las preguntas, el 2 el modelo, el 3 la base, y acá empiezan a salir las respuestas.

**Autor:** Leopoldo Nasela · **Comisión:** [completar]

---

## Contenido

```
.
├── m4_consultas_negocio.sql   ← las 4 consultas pedidas
├── schema.sql                 ← crea las tablas y carga los datos de prueba
└── README.md
```

## Cómo ejecutar

```bash
psql -U postgres -c "CREATE DATABASE retailpro;"
psql -U postgres -d retailpro -f schema.sql
psql -U postgres -d retailpro -f m4_consultas_negocio.sql
```

Verificado sobre PostgreSQL 16. Los datos de prueba cubren **enero a junio de 2024** con 30 operaciones, 7 clientes y 8 productos, para que las agregaciones por mes y la comparación contra el promedio devuelvan resultados interpretables.

---

## Consulta 1 — Resumen ejecutivo mensual

**Pregunta:** ¿cómo evolucionó la facturación mes a mes, y esa variación viene de vender más veces o de vender más caro?

| mes | cantidad_pedidos | total_facturado | ticket_promedio |
|---|---|---|---|
| 1 | 4 | 1.980,00 | 495,00 |
| 2 | 4 | 2.100,00 | 525,00 |
| 3 | 10 | 6.444,00 | 644,40 |
| 4 | 4 | 1.033,00 | 258,25 |
| 5 | 4 | 3.976,00 | 994,00 |
| 6 | 4 | 2.020,00 | 505,00 |

**Lectura:** marzo factura el triple que enero, pero por un motivo distinto al de mayo. Marzo crece **por volumen** (10 pedidos contra 4), mientras que mayo lo hace **por ticket** (mismos 4 pedidos, pero de 994 promedio contra 258 de abril). Son dos fenómenos que piden acciones comerciales opuestas, y el total facturado solo no los distingue. Por eso las tres métricas van juntas.

Las tres se calculan en una sola pasada: `COUNT(*)` cuenta filas, `SUM()` acumula y `AVG()` promedia, todas sobre los grupos que arma el `GROUP BY`.

---

## Consulta 2 — Ranking de productos (Top 5)

**Pregunta:** ¿qué productos concentran la facturación?

| id_producto | unidades_vendidas | total_facturado |
|---|---|---|
| 1 | 8 | 9.600,00 |
| 3 | 7 | 3.150,00 |
| 4 | 12 | 1.440,00 |
| 5 | 9 | 1.170,00 |
| 2 | 41 | 1.148,00 |

**Lectura:** el producto 2 (Mouse Inalámbrico) vendió **41 unidades**, cinco veces más que cualquier otro, y queda último en facturación. El producto 1 (Laptop Pro 15) vendió 8 unidades y factura ocho veces más que él.

Esa es la razón de mostrar las dos columnas juntas: *más vendido* y *el que más factura* son dos rankings distintos, y confundirlos lleva a decisiones malas. Si el reporte mostrara solo unidades, el mouse parecería el producto estrella.

`ORDER BY total_facturado DESC` + `LIMIT 5` es lo que convierte una agregación en un ranking: sin el `ORDER BY`, el `LIMIT` devuelve cinco filas cualesquiera.

---

## Consulta 3 — Clientes recurrentes

**Pregunta:** ¿qué clientes volvieron a comprar y cuánto gastaron en total?

| id_cliente | cantidad_pedidos | total_gastado |
|---|---|---|
| 1 | 7 | 6.138,00 |
| 3 | 6 | 4.854,00 |
| 5 | 5 | 2.700,00 |
| 4 | 5 | 2.055,00 |
| 2 | 7 | 1.806,00 |

**Lectura:** los clientes 1 y 2 tienen la misma cantidad de pedidos (7) y una diferencia de más del triple en lo que gastaron. La frecuencia de compra y el valor del cliente no son lo mismo: una campaña de retención dirigida "a los que más compran" por cantidad de pedidos trataría a los dos igual, y no deberían recibir el mismo esfuerzo comercial.

### Por qué HAVING y no WHERE

Es la distinción central de esta consulta:

```sql
-- Correcto
GROUP BY id_cliente
HAVING COUNT(*) > 1

-- Error: la columna no existe todavía en ese punto
WHERE COUNT(*) > 1
```

`WHERE` filtra **filas individuales antes** de agrupar. `HAVING` filtra **grupos ya formados**, cuando el `COUNT` existe. Un `WHERE` no puede evaluar un valor que todavía no se calculó, y el motor devuelve un error de sintaxis.

La regla práctica: si la condición menciona una función de agregación, va en `HAVING`; si menciona una columna cruda, va en `WHERE`.

---

## Consulta 4 — Meses por encima / por debajo del promedio

**Pregunta:** ¿qué meses rindieron mejor o peor que el promedio del período?

| mes | total_facturado | promedio_mensual | situación |
|---|---|---|---|
| 1 | 1.980,00 | 2.925,50 | Por debajo |
| 2 | 2.100,00 | 2.925,50 | Por debajo |
| 3 | 6.444,00 | 2.925,50 | **Por encima** |
| 4 | 1.033,00 | 2.925,50 | Por debajo |
| 5 | 3.976,00 | 2.925,50 | **Por encima** |
| 6 | 2.020,00 | 2.925,50 | Por debajo |

**Lectura:** cuatro de los seis meses quedan por debajo del promedio. No es una contradicción: dos meses muy fuertes (marzo y mayo) empujan el promedio hacia arriba y dejan a la mayoría abajo. Es el caso clásico donde el promedio describe mal al conjunto, y vale la pena mirar también la mediana antes de fijar una meta mensual con este número.

### Por qué hace falta un CTE

El promedio mensual no se puede calcular en la misma pasada que lo compara: primero hay que tener los totales de cada mes, y recién después promediarlos. El CTE (`WITH totales_mensuales AS ...`) resuelve el primer paso y lo deja disponible como si fuera una tabla.

El error a evitar es escribir `AVG(cantidad * precio_unitario)` sobre la tabla cruda: eso devuelve el promedio **por línea de venta**, no por mes. Son números distintos y el segundo es el que pide la consigna.

`CASE WHEN` es lo que traduce un número en una categoría legible. El gerente que lee el reporte no compara 1.980,00 contra 2.925,50 mentalmente: lee "Por debajo" y sigue.

---

## Conexión con el brief del Módulo 1

| Consulta | Pregunta de análisis del M1 |
|---|---|
| 1 — Resumen mensual | P4: en qué mes se rompe la tendencia y cómo se comporta la estacionalidad |
| 2 — Ranking de productos | P2: qué productos concentran la facturación y cuáles la compensan |
| 3 — Clientes recurrentes | P3 y P6: si la caída es por menos clientes o menor gasto, y qué cuentas concentran la facturación |
| 4 — Meses vs. promedio | P4: detección de los meses fuera de la norma |

---

## Criterios de aceptación

- [x] Las cuatro consultas se ejecutan sin errores (verificado en PostgreSQL 16).
- [x] Consulta 1 agrupa por mes con `EXTRACT(MONTH FROM fecha_venta)` y usa alias en español.
- [x] Consulta 2 usa `GROUP BY id_producto`, `ORDER BY` y limita a 5 resultados.
- [x] Consulta 3 usa `GROUP BY id_cliente` y `HAVING COUNT(*) > 1`.
- [x] Consulta 4 etiqueta con `CASE WHEN` según el promedio mensual general.
- [x] El repositorio es público y contiene `m4_consultas_negocio.sql`.

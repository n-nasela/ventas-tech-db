-- ══════════════════════════════════════════════════════════════════
-- RetailPro — Pre-entrega 4: Consultas SQL de negocio
-- Resumen de agregaciones: COUNT, SUM, AVG, MIN, MAX
-- Autor: Leopoldo Nasela
-- Fecha: [completar]
-- Motor: PostgreSQL 16
-- ══════════════════════════════════════════════════════════════════
-- Requisito previo: ejecutar schema.sql, que crea las tablas y carga
-- los datos de prueba (enero a junio de 2024).
-- ══════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────
-- CONSULTA 1 — Resumen ejecutivo mensual
-- ──────────────────────────────────────────────────────────────────
-- Pregunta de negocio: ¿cómo evolucionó la facturación mes a mes, y
-- esa variación viene de vender más veces o de vender más caro?
--
-- Por eso las tres métricas van juntas: el total solo no distingue
-- entre "más pedidos" y "pedidos más grandes". El ticket promedio es
-- el que separa una cosa de la otra.
--
-- El total de cada línea es cantidad * precio_unitario. Se usa
-- precio_unitario (el precio cobrado en esa venta) y no el precio de
-- productos, que es el de lista vigente hoy.
-- ──────────────────────────────────────────────────────────────────
SELECT
    EXTRACT(MONTH FROM fecha_venta)              AS mes,
    COUNT(*)                                     AS cantidad_pedidos,
    SUM(cantidad * precio_unitario)              AS total_facturado,
    ROUND(AVG(cantidad * precio_unitario), 2)    AS ticket_promedio
FROM ventas
GROUP BY EXTRACT(MONTH FROM fecha_venta)
ORDER BY mes;


-- ──────────────────────────────────────────────────────────────────
-- CONSULTA 2 — Ranking de productos (Top 5 por facturación)
-- ──────────────────────────────────────────────────────────────────
-- Pregunta de negocio: ¿qué productos concentran la facturación?
--
-- Se muestran unidades y facturación en la misma fila a propósito:
-- son dos rankings distintos. Un producto barato puede liderar en
-- unidades y no aparecer entre los que más facturan, y esa diferencia
-- es justamente la que define si conviene empujar volumen o margen.
-- ──────────────────────────────────────────────────────────────────
SELECT
    id_producto,
    SUM(cantidad)                        AS unidades_vendidas,
    SUM(cantidad * precio_unitario)      AS total_facturado
FROM ventas
GROUP BY id_producto
ORDER BY total_facturado DESC
LIMIT 5;


-- ──────────────────────────────────────────────────────────────────
-- CONSULTA 3 — Clientes recurrentes
-- ──────────────────────────────────────────────────────────────────
-- Pregunta de negocio: ¿qué clientes volvieron a comprar y cuánto
-- gastaron en total? Son las cuentas sobre las que conviene trabajar
-- la retención.
--
-- HAVING y no WHERE: WHERE filtra filas ANTES de agrupar, y acá hay
-- que filtrar DESPUÉS, sobre el resultado del COUNT. Un WHERE no
-- puede ver un valor que todavía no se calculó.
-- ──────────────────────────────────────────────────────────────────
SELECT
    id_cliente,
    COUNT(*)                             AS cantidad_pedidos,
    SUM(cantidad * precio_unitario)      AS total_gastado
FROM ventas
GROUP BY id_cliente
HAVING COUNT(*) > 1
ORDER BY total_gastado DESC;


-- ──────────────────────────────────────────────────────────────────
-- CONSULTA 4 — Meses por encima / por debajo del promedio
-- ──────────────────────────────────────────────────────────────────
-- Pregunta de negocio: ¿qué meses rindieron mejor o peor que el
-- promedio del período?
--
-- Hay que resolverlo en dos pasos porque el promedio mensual no se
-- puede calcular en la misma pasada que lo compara: primero el CTE
-- arma el total de cada mes, y recién después se compara cada mes
-- contra el promedio de esos totales.
--
-- Error a evitar: AVG(cantidad * precio_unitario) sobre la tabla
-- cruda NO es el promedio mensual, es el promedio por línea de venta.
-- ──────────────────────────────────────────────────────────────────
WITH totales_mensuales AS (
    SELECT
        EXTRACT(MONTH FROM fecha_venta)      AS mes,
        SUM(cantidad * precio_unitario)      AS total_facturado
    FROM ventas
    GROUP BY EXTRACT(MONTH FROM fecha_venta)
)
SELECT
    mes,
    total_facturado,
    ROUND((SELECT AVG(total_facturado) FROM totales_mensuales), 2) AS promedio_mensual,
    CASE
        WHEN total_facturado >= (SELECT AVG(total_facturado) FROM totales_mensuales)
            THEN 'Por encima'
        ELSE 'Por debajo'
    END                                                            AS situacion
FROM totales_mensuales
ORDER BY mes;

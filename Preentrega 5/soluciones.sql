-- ══════════════════════════════════════════════════════════════════
-- RetailPro — Pre-entrega 5: Consultas con JOIN y UNION
-- Autor: Leopoldo Nasela
-- Fecha: [completar]
-- Motor: PostgreSQL 16
-- ══════════════════════════════════════════════════════════════════
-- Requisito previo: ejecutar schema.sql (crea las tablas y carga los
-- datos de prueba).
-- ══════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────
-- CONSULTA 1 — Vista base del proyecto (INNER JOIN)
-- ──────────────────────────────────────────────────────────────────
-- Es la consulta más importante del módulo: va a ser la fuente de
-- datos principal en Power BI. Reconstruye, en una sola fila, todo lo
-- que una venta significa en términos de negocio.
--
-- La tabla ventas sola es ilegible: guarda id_cliente = 3 e
-- id_producto = 1. Los INNER JOIN traen el nombre detrás de cada id.
--
-- Se usa INNER JOIN y no LEFT porque acá queremos exactamente las
-- ventas que tienen cliente y producto válidos. Como las claves
-- foráneas son NOT NULL, no se pierde ninguna fila: las 30 ventas
-- entran. Si alguna se perdiera, sería señal de un problema de
-- integridad en la base.
--
-- Columnas para agrupar en Power BI: segmento, region, zona,
-- nombre_categoria. Columnas para filtrar: fecha_venta, ciudad.
-- ──────────────────────────────────────────────────────────────────
SELECT
    v.id_venta,
    v.fecha_venta,
    c.nombre                              AS cliente,
    c.segmento                            AS segmento_cliente,
    c.ciudad,
    t.region,
    t.zona,
    p.nombre_producto                     AS producto,
    cat.nombre_categoria                  AS categoria,
    v.cantidad,
    v.precio_unitario,
    v.cantidad * v.precio_unitario        AS total_venta
FROM ventas v
INNER JOIN clientes    c   ON v.id_cliente   = c.id_cliente
INNER JOIN territorios t   ON c.id_territorio = t.id_territorio
INNER JOIN productos   p   ON v.id_producto  = p.id_producto
INNER JOIN categorias  cat ON p.id_categoria = cat.id_categoria
ORDER BY v.fecha_venta, v.id_venta;


-- ──────────────────────────────────────────────────────────────────
-- CONSULTA 2 — Clientes sin ventas (LEFT JOIN)
-- ──────────────────────────────────────────────────────────────────
-- Pregunta de negocio: ¿qué clientes se registraron y nunca compraron?
-- Son los candidatos a una campaña de activación.
--
-- Acá el INNER JOIN no sirve: justamente descartaría a los clientes
-- que no tienen ninguna venta, que son los que buscamos. El LEFT JOIN
-- conserva TODOS los clientes y completa con NULL los que no tienen
-- correspondencia en ventas.
--
-- WHERE v.id_venta IS NULL es el filtro que aísla esos casos: si no
-- hubo match, todas las columnas de ventas quedaron en NULL.
-- ──────────────────────────────────────────────────────────────────
SELECT
    c.id_cliente,
    c.nombre,
    c.email,
    c.fecha_registro
FROM clientes c
LEFT JOIN ventas v ON c.id_cliente = v.id_cliente
WHERE v.id_venta IS NULL
ORDER BY c.fecha_registro;


-- ──────────────────────────────────────────────────────────────────
-- CONSULTA 3 — Productos sin ventas (LEFT JOIN)
-- ──────────────────────────────────────────────────────────────────
-- Pregunta de negocio: ¿qué productos están en catálogo, ocupando
-- stock, y nunca se vendieron? Es capital inmovilizado.
--
-- Misma lógica que la consulta anterior, pero del lado del catálogo.
-- Se suma la categoría con un INNER JOIN adicional: ese sí puede ser
-- INNER porque todo producto tiene categoría obligatoria (la FK es
-- NOT NULL).
-- ──────────────────────────────────────────────────────────────────
SELECT
    p.id_producto,
    p.nombre_producto,
    cat.nombre_categoria                  AS categoria,
    p.precio,
    p.stock,
    p.precio * p.stock                    AS capital_inmovilizado
FROM productos p
INNER JOIN categorias cat ON p.id_categoria = cat.id_categoria
LEFT  JOIN ventas     v   ON p.id_producto  = v.id_producto
WHERE v.id_venta IS NULL
ORDER BY capital_inmovilizado DESC;


-- ──────────────────────────────────────────────────────────────────
-- CONSULTA 4 — Consolidado por canal (UNION ALL)
-- ──────────────────────────────────────────────────────────────────
-- Pregunta de negocio: ¿cuánto factura cada canal de venta?
--
-- La columna canal NO existe en ninguna tabla: se crea como texto
-- literal dentro de cada SELECT. Ese es el punto del ejercicio.
--
-- CRITERIO DE SEPARACIÓN APLICADO
--   RetailPro tiene local físico en las ciudades donde está la
--   sucursal (Buenos Aires, Córdoba y Rosario): esas ventas se
--   registran como 'Presencial'. En el resto del país la operación es
--   a distancia, y se registra como 'Online'.
--   El criterio se declara acá porque la base no lo guarda: si en el
--   futuro se agrega una columna canal en ventas, esta consulta se
--   reemplaza por un GROUP BY directo sobre esa columna.
--
-- UNION ALL y no UNION: UNION elimina las filas duplicadas, y acá dos
-- ventas distintas pueden coincidir en todos sus valores (mismo
-- canal, misma fecha, mismo importe). Con UNION se perdería una de
-- las dos y el total facturado quedaría mal. Cada venta debe contarse
-- una sola vez, pero TODAS las veces que ocurrió.
--
-- Las dos consultas apiladas devuelven la misma cantidad de columnas,
-- en el mismo orden y con tipos compatibles: es el requisito para que
-- UNION ALL funcione.
-- ──────────────────────────────────────────────────────────────────
WITH ventas_por_canal AS (

    SELECT
        v.fecha_venta,
        v.cantidad * v.precio_unitario    AS total,
        'Presencial'                      AS canal
    FROM ventas v
    INNER JOIN clientes c ON v.id_cliente = c.id_cliente
    WHERE c.ciudad IN ('Buenos Aires', 'Córdoba', 'Rosario')

    UNION ALL

    SELECT
        v.fecha_venta,
        v.cantidad * v.precio_unitario    AS total,
        'Online'                          AS canal
    FROM ventas v
    INNER JOIN clientes c ON v.id_cliente = c.id_cliente
    WHERE c.ciudad NOT IN ('Buenos Aires', 'Córdoba', 'Rosario')

)
SELECT
    canal,
    COUNT(*)                              AS cantidad_ventas,
    SUM(total)                            AS total_facturado,
    ROUND(AVG(total), 2)                  AS ticket_promedio,
    MIN(fecha_venta)                      AS primera_venta,
    MAX(fecha_venta)                      AS ultima_venta
FROM ventas_por_canal
GROUP BY canal
ORDER BY total_facturado DESC;


-- ──────────────────────────────────────────────────────────────────
-- CONTROL: por qué UNION ALL y no UNION
-- ──────────────────────────────────────────────────────────────────
-- Las dos consultas son idénticas salvo por el operador. La primera
-- cuenta las 30 ventas reales; la segunda, las que sobreviven a la
-- deduplicación de UNION. La diferencia son las ventas distintas que
-- coinciden en canal e importe y que UNION colapsa en una sola fila.
-- ──────────────────────────────────────────────────────────────────
SELECT 'UNION ALL (correcto)' AS metodo, COUNT(*) AS filas_resultantes
FROM (
    SELECT 'Presencial' AS canal, v.cantidad * v.precio_unitario AS total
    FROM ventas v INNER JOIN clientes c ON v.id_cliente = c.id_cliente
    WHERE c.ciudad IN ('Buenos Aires', 'Córdoba', 'Rosario')
    UNION ALL
    SELECT 'Online', v.cantidad * v.precio_unitario
    FROM ventas v INNER JOIN clientes c ON v.id_cliente = c.id_cliente
    WHERE c.ciudad NOT IN ('Buenos Aires', 'Córdoba', 'Rosario')
) AS t

UNION ALL

SELECT 'UNION (pierde ventas)', COUNT(*)
FROM (
    SELECT 'Presencial' AS canal, v.cantidad * v.precio_unitario AS total
    FROM ventas v INNER JOIN clientes c ON v.id_cliente = c.id_cliente
    WHERE c.ciudad IN ('Buenos Aires', 'Córdoba', 'Rosario')
    UNION
    SELECT 'Online', v.cantidad * v.precio_unitario
    FROM ventas v INNER JOIN clientes c ON v.id_cliente = c.id_cliente
    WHERE c.ciudad NOT IN ('Buenos Aires', 'Córdoba', 'Rosario')
) AS t2;

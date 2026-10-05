# RetailPro — Pre-entrega 5: Consultas con JOIN y UNION

Cruce de tablas (`INNER JOIN`, `LEFT JOIN`) y apilado de resultados (`UNION ALL`) sobre la base de RetailPro. Quinta pieza del proyecto integrador.

**Autor:** Leopoldo Nasela · **Comisión:** [completar]

---

## Contenido

```
.
├── schema.sql       ← crea las tablas y carga los datos de prueba
├── soluciones.sql   ← las 4 consultas resueltas
└── README.md
```

## Cómo ejecutar

```bash
psql -U postgres -c "CREATE DATABASE retailpro;"
psql -U postgres -d retailpro -f schema.sql
psql -U postgres -d retailpro -f soluciones.sql
```

Verificado sobre PostgreSQL 16.

## Ampliaciones al esquema del Módulo 3

La consigna pide que, si el esquema no tiene dimensión geográfica ni de segmentación, se agregue ahora, porque la Consulta 1 va a ser la fuente de datos principal en Power BI. Se incorporaron:

- **Tabla `territorios`** (`region`, `pais`, `zona`), referenciada desde `clientes`. Son las columnas para **agrupar**.
- **Columna `segmento`** en `clientes` (Minorista / Mayorista / Corporativo), con `CHECK` que limita los valores admitidos. Es la columna para **filtrar**.

Ambas ya estaban previstas en el modelo entregado en el Módulo 2, así que esto alinea la base con ese diseño. Los datos de prueba se ampliaron a 30 ventas entre enero y junio de 2024, con dos clientes y dos productos deliberadamente sin ventas: son los que aíslan las consultas 2 y 3.

---

## Consulta 1 — Vista base del proyecto (INNER JOIN)

La más importante del módulo: es la fuente de datos que va a consumir Power BI.

La tabla `ventas` sola es ilegible. Guarda `id_cliente = 3` e `id_producto = 1`, y ningún stakeholder puede leer eso. Los `INNER JOIN` reconstruyen, en una sola fila, lo que la venta significa en términos de negocio.

Devuelve las **30 ventas** con 12 columnas. Primeras filas:

| fecha | cliente | segmento | región | producto | categoría | cant. | precio | total |
|---|---|---|---|---|---|---|---|---|
| 2024-01-08 | María López | Corporativo | Centro | Laptop Pro 15 | Computación | 1 | 1200,00 | 1200,00 |
| 2024-01-15 | Carlos Ruiz | Minorista | Centro | Mouse Inalámbrico | Accesorios | 5 | 28,00 | 140,00 |
| 2024-01-22 | Ana Gómez | Mayorista | Litoral | Teclado Mecánico | Accesorios | 2 | 95,00 | 190,00 |

### Por qué INNER y no LEFT

Acá queremos exactamente las ventas que tienen cliente y producto válidos. Como las claves foráneas son `NOT NULL`, **no se pierde ninguna fila**: entran las 30.

Eso en sí mismo es un control de integridad. Si esta consulta devolviera menos de 30 filas, significaría que hay ventas apuntando a un cliente o un producto inexistente, y habría que revisar la carga antes de seguir.

### Columnas pensadas para Power BI

| Para agrupar | Para filtrar | Para medir |
|---|---|---|
| `segmento_cliente`, `region`, `zona`, `categoria` | `fecha_venta`, `ciudad` | `cantidad`, `precio_unitario`, `total_venta` |

`total_venta` se calcula en la consulta (`cantidad * precio_unitario`) en lugar de leerse de una columna: el precio que se usa es el cobrado en esa operación, no el de lista vigente hoy.

---

## Consulta 2 — Clientes sin ventas (LEFT JOIN)

**Pregunta:** ¿qué clientes se registraron y nunca compraron? Son los candidatos a una campaña de activación.

| id_cliente | nombre | email | fecha_registro |
|---|---|---|---|
| 6 | Diego Fernández | diego@mail.com | 2024-04-02 |
| 7 | Sofía Ramos | sofia@mail.com | 2024-05-20 |

### Por qué el INNER JOIN no sirve acá

Es el punto central de la consulta. Un `INNER JOIN` devuelve solo las filas con correspondencia en ambas tablas, así que **descartaría exactamente a los clientes que estamos buscando**: los que no tienen ninguna venta.

El `LEFT JOIN` conserva todos los clientes y completa con `NULL` las columnas de `ventas` cuando no hubo match:

```sql
FROM clientes c
LEFT JOIN ventas v ON c.id_cliente = v.id_cliente
WHERE v.id_venta IS NULL
```

`WHERE v.id_venta IS NULL` es el filtro que aísla esos casos. Se usa la clave primaria de `ventas` y no cualquier columna: al ser `NOT NULL` en la tabla, si aparece en `NULL` solo puede deberse a que el `LEFT JOIN` no encontró pareja.

**Error a evitar:** poner la condición de la tabla derecha en el `WHERE` en lugar del `ON` convierte silenciosamente un `LEFT JOIN` en un `INNER JOIN`, porque filtra las filas con `NULL` antes de que puedas verlas.

---

## Consulta 3 — Productos sin ventas (LEFT JOIN)

**Pregunta:** ¿qué productos están en catálogo, ocupando stock, y nunca se vendieron?

| id_producto | producto | categoría | precio | stock | capital_inmovilizado |
|---|---|---|---|---|---|
| 8 | Parlante Bluetooth | Audio | 85,00 | 30 | 2.550,00 |
| 7 | Webcam HD 1080 | Accesorios | 60,00 | 25 | 1.500,00 |

Misma mecánica que la anterior, del lado del catálogo. Se agregó la columna `capital_inmovilizado` (`precio * stock`) porque convierte el dato en una decisión: no es lo mismo que sobren 2 unidades de algo barato que 4.050 pesos parados en mercadería que no rota.

La consulta combina los dos tipos de JOIN a propósito:

- `INNER JOIN categorias` — todo producto tiene categoría obligatoria (la FK es `NOT NULL`), así que no se pierde nada.
- `LEFT JOIN ventas` — es el que tiene que conservar los productos sin correspondencia.

---

## Consulta 4 — Consolidado por canal (UNION ALL)

**Pregunta:** ¿cuánto factura cada canal de venta?

| canal | cantidad_ventas | total_facturado | ticket_promedio | primera_venta | última_venta |
|---|---|---|---|---|---|
| Presencial | 20 | 12.798,00 | 639,90 | 2024-01-08 | 2024-06-25 |
| Online | 10 | 4.755,00 | 475,50 | 2024-02-05 | 2024-06-04 |

**Lectura:** lo presencial no solo vende el doble de veces, sino con un ticket 35% más alto. El canal online no está compitiendo en el mismo rango de compra.

### La columna canal se crea, no se consulta

`canal` no existe en ninguna tabla de la base. Se genera como **texto literal** dentro de cada `SELECT`:

```sql
SELECT fecha_venta, total, 'Presencial' AS canal FROM ventas ... WHERE ...
UNION ALL
SELECT fecha_venta, total, 'Online'     AS canal FROM ventas ... WHERE ...
```

### Criterio de separación aplicado

RetailPro tiene local físico en las ciudades donde hay sucursal (Buenos Aires, Córdoba y Rosario): esas ventas se registran como **Presencial**. En el resto del país la operación es a distancia: **Online**.

El criterio se declara en el código porque la base no lo guarda. Si en el futuro se agrega una columna `canal` en `ventas`, esta consulta se reemplaza por un `GROUP BY` directo sobre esa columna, y el dato pasa a ser un hecho en lugar de un supuesto.

### Por qué UNION ALL y no UNION

Esta es la parte que más se presta a error, así que la consulta final del script lo demuestra con números:

| Método | Filas resultantes |
|---|---|
| `UNION ALL` (correcto) | **30** |
| `UNION` | 22 |

`UNION` elimina las filas duplicadas. Dos ventas **distintas** pueden coincidir en todos sus valores: mismo canal y mismo importe, como las tres ventas de 1.200 en el canal Presencial. `UNION` las colapsa en una sola fila y se pierden 8 operaciones reales, con lo que el total facturado queda mal.

Cada venta debe contarse una sola vez, pero **todas las veces que ocurrió**. Esa diferencia es la que define cuál de los dos operadores corresponde.

### Requisitos que cumple el UNION ALL

Las dos consultas apiladas devuelven la misma cantidad de columnas, en el mismo orden y con tipos compatibles (`DATE`, `DECIMAL`, `VARCHAR`). Si fallara cualquiera de las tres condiciones, el motor rechaza la consulta.

---

## Resumen: qué JOIN usar

| Necesidad | JOIN | Por qué |
|---|---|---|
| Solo las filas que cruzan en ambas tablas | `INNER` | Descarta lo que no tiene pareja |
| Todas las de la izquierda, tengan o no pareja | `LEFT` | Conserva la tabla principal y completa con NULL |
| Aislar lo que **no** cruza | `LEFT` + `WHERE ... IS NULL` | El NULL es la señal de que no hubo match |
| Apilar resultados de dos consultas | `UNION ALL` | Conserva todas las filas, incluidas las repetidas |

---

## Criterios de aceptación

- [x] Las cuatro consultas se ejecutan sin errores (PostgreSQL 16).
- [x] Consulta 1 combina `ventas` con todas las dimensiones mediante `INNER JOIN` y devuelve fecha, cliente, producto, cantidad, precio unitario y total, más segmento, región, zona y categoría.
- [x] Consultas 2 y 3 usan `LEFT JOIN` con `WHERE ... IS NULL` y devuelven filas.
- [x] Consulta 4 crea la columna `canal` como literal, apila con `UNION ALL` y cierra con `GROUP BY`.
- [x] El repositorio es público y contiene `schema.sql`, `soluciones.sql` y `README.md`.

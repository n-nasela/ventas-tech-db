# Ventas_Tech_DB — Script de ingeniería de datos

Base de datos relacional de **TechStore**, una cadena de tiendas de tecnología. Este repositorio contiene el script SQL que crea el esquema completo, define las restricciones de integridad y carga los datos iniciales.

Es el back-end del proyecto de certificación: el dashboard final se alimenta de esta base.

---

## Contenido del repositorio

```
.
└── modulo-03/
    ├── ventas_tech_db.sql   ← script completo (DDL + constraints + DML + verificación)
    └── modelo_er.png        ← diagrama entidad-relación
```

---

## Modelo de datos

![Modelo entidad-relación de Ventas_Tech_DB](modulo-03/modelo_er.png)

```
categorias (1) ──< (N) productos (1) ──< (N) ventas (N) >── (1) clientes
```

| Tabla | Rol | Filas cargadas |
|---|---|---|
| `categorias` | Dimensión. Existe como tabla propia para cumplir 3NF. | 4 |
| `clientes` | Dimensión. Quiénes compran. | 5 |
| `productos` | Dimensión. Qué se vende. Referencia a `categorias`. | 6 |
| `ventas` | Tabla de hechos. Conecta clientes y productos. | 10 |

---

## Cómo ejecutar el script

### PostgreSQL (psql)

```bash
# 1. Crear la base de datos
psql -U postgres -c "CREATE DATABASE ventas_tech_db;"

# 2. Ejecutar el script dentro de esa base
psql -U postgres -d ventas_tech_db -f modulo-03/ventas_tech_db.sql
```

### PostgreSQL (pgAdmin)

1. Crear la base `Ventas_Tech_DB` desde el panel izquierdo.
2. Abrir la *Query Tool* **conectada a esa base**.
3. Abrir `ventas_tech_db.sql` y ejecutarlo completo (F5).

> La sentencia `CREATE DATABASE` está comentada al inicio del script a propósito: PostgreSQL no permite crear una base y usarla en el mismo lote, porque hay que reconectarse.

### SQL Server

El script es compatible sin cambios. La única adaptación ya aplicada es el tipo de la columna `activo`: la consigna indicaba `TINYINT(1)`, que es sintaxis de MySQL, y se reemplazó por `SMALLINT` con un `CHECK (activo IN (0,1))`, que funciona igual en ambos motores.

---

## Estructura del script

| Sección | Contenido |
|---|---|
| **0** | `CREATE DATABASE` (comentado, se ejecuta por separado) |
| **1 — DDL** | `DROP TABLE` en orden inverso de dependencias + `CREATE TABLE` de las 4 tablas |
| **2 — Restricciones** | PK, FK, UNIQUE, CHECK e índices, declarados con `ALTER TABLE` y nombres explícitos |
| **3 — DML** | `INSERT` en orden directo de dependencias |
| **4 — Verificación** | Consultas de control de carga e integridad |

### El script es repetible

Se puede ejecutar tantas veces como se quiera sin errores: empieza eliminando las tablas si existen, en el orden inverso al de las dependencias (`ventas` → `productos` → `clientes` → `categorias`). Verificado con tres ejecuciones consecutivas.

---

## Decisiones técnicas

**`DECIMAL(10,2)` para importes, nunca `FLOAT`.** Los tipos de punto flotante introducen errores de redondeo inaceptables en cifras monetarias.

**Restricciones nombradas (`pk_`, `fk_`, `uq_`, `chk_`).** Cuando el motor rechaza una operación, el mensaje de error indica exactamente qué regla se violó, en lugar de un identificador autogenerado.

**`ON DELETE RESTRICT` en todas las claves foráneas.** Impide borrar un cliente, un producto o una categoría que tenga historial asociado. Para datos de ventas es la política correcta: el pasado no se elimina en cascada.

**`precio_unitario` se guarda en `ventas`.** No es redundante con `productos.precio`: uno es el precio de lista vigente hoy y el otro es el precio efectivamente cobrado en esa operación. Si se leyera el precio actual, cualquier actualización de la lista reescribiría la historia de facturación.

**Índices explícitos sobre las FK.** PostgreSQL indexa automáticamente las claves primarias, pero no las foráneas, y todos los JOIN del análisis pasan por esas columnas.

**Restricciones `CHECK` además de las FK.** Las FK protegen las relaciones; los CHECK protegen los valores. Sin ellos la base aceptaría ventas de cero unidades o precios negativos, y esos registros contaminarían después todos los KPIs.

---

## Verificación

Salida obtenida al ejecutar la sección 4 sobre PostgreSQL 16:

**Recuento de filas**

| tabla | filas |
|---|---|
| categorias | 4 |
| clientes | 5 |
| productos | 6 |
| ventas | 10 |

**Integridad referencial:** 0 ventas huérfanas, 0 productos sin categoría.

**Consulta de negocio de muestra** (facturación por categoría):

| categoría | operaciones | unidades | facturación |
|---|---|---|---|
| Computación | 4 | 6 | 4950.00 |
| Accesorios | 3 | 17 | 744.00 |
| Almacenamiento | 1 | 3 | 390.00 |
| Audio | 2 | 3 | 360.00 |

### Pruebas negativas

Se comprobó que las restricciones efectivamente rechazan datos inválidos:

| Operación intentada | Restricción que la bloquea |
|---|---|
| Venta de un producto inexistente | `fk_ventas_producto` |
| Venta con `cantidad = 0` | `chk_ventas_cantidad` |
| Cliente con un email ya registrado | `uq_clientes_email` |
| Borrar una categoría que tiene productos | `fk_productos_categoria` (RESTRICT) |
| Producto con `precio` nulo | `NOT NULL` |

---

## Criterios de aceptación

- [x] El script se ejecuta sin errores en PostgreSQL.
- [x] Las foreign keys están definidas en `productos` y `ventas`.
- [x] No se permiten nulos en las columnas marcadas `NOT NULL`.
- [x] El `DROP TABLE` respeta el orden inverso de dependencias.
- [x] Las 4 tablas se cargan sin errores y `ventas` contiene 10 registros.
- [x] El script es repetible.

---

**Autor:** [completar] · **Comisión:** [completar]

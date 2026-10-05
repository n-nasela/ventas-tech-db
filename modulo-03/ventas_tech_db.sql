-- =====================================================================
--  Ventas_Tech_DB — Script de ingeniería de datos
--  Módulo 3 · Checkpoint: Script SQL de Ingeniería de Datos
--  Motor objetivo: PostgreSQL 13+ (compatible con SQL Server 2016+)
--  Autor: Leopoldo Nasela
--  Última actualización: 06/09/2026
-- =====================================================================
--
--  CONTENIDO DEL SCRIPT
--    Sección 0 — Creación de la base de datos (se ejecuta por separado)
--    Sección 1 — DDL: limpieza y definición del esquema
--    Sección 2 — Restricciones de integridad (PK, FK, UNIQUE, CHECK)
--    Sección 3 — DML: carga inicial de datos
--    Sección 4 — Consultas de verificación
--
--  MODELO DE DATOS
--    categorias (1) ──< (N) productos (1) ──< (N) ventas (N) >── (1) clientes
--
--  El script es REPETIBLE: puede ejecutarse tantas veces como se quiera
--  sin errores, porque comienza eliminando las tablas si ya existen.
-- =====================================================================


-- =====================================================================
-- SECCIÓN 0 — CREACIÓN DE LA BASE DE DATOS
-- ---------------------------------------------------------------------
-- PostgreSQL no permite ejecutar CREATE DATABASE dentro del mismo lote
-- que crea las tablas, porque hay que reconectarse a la base nueva.
-- Por eso la sentencia queda comentada: ejecutala una sola vez y después
-- conectate a Ventas_Tech_DB para correr el resto del script.
--
--   CREATE DATABASE Ventas_Tech_DB;
--   \c ventas_tech_db          -- (en psql)
-- =====================================================================


-- =====================================================================
-- SECCIÓN 1 — DDL: LIMPIEZA Y DEFINICIÓN DEL ESQUEMA
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1.1 Eliminación de tablas previas
-- El orden es el INVERSO al de las dependencias: primero las tablas que
-- contienen claves foráneas y al final las que son referenciadas. Si se
-- intentara borrar 'categorias' antes que 'productos', el motor lo
-- rechazaría porque productos todavía apunta a ella.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS categorias;


-- ---------------------------------------------------------------------
-- 1.2 Creación de tablas
-- Orden lógico: primero las dimensiones (tablas sin dependencias) y al
-- final la tabla de hechos. Así se evita el error del "huevo y la
-- gallina": ninguna FK apunta a una tabla que todavía no existe.
-- ---------------------------------------------------------------------

-- Tabla 1: categorias --------------------------------------------------
-- Dimensión. Existe como tabla separada para cumplir la 3NF: la
-- categoría NO se guarda como texto dentro de productos, porque eso
-- generaría una dependencia transitiva (id_producto -> categoria) y
-- repetiría el mismo literal en cada fila del catálogo.
CREATE TABLE categorias (
    id_categoria      INT           NOT NULL,
    nombre_categoria  VARCHAR(50)   NOT NULL,
    descripcion       VARCHAR(200)
);

-- Tabla 2: clientes ----------------------------------------------------
-- Dimensión. Un registro por cliente. 'email' se declara UNIQUE en la
-- sección 2 para impedir cuentas duplicadas.
CREATE TABLE clientes (
    id_cliente        INT           NOT NULL,
    nombre            VARCHAR(100)  NOT NULL,
    email             VARCHAR(100),
    ciudad            VARCHAR(50),
    fecha_registro    DATE          NOT NULL
);

-- Tabla 3: productos ---------------------------------------------------
-- Dimensión con dependencia hacia categorias.
-- Nota: La consigna indica TINYINT(1) para 'activo', que
-- es un tipo propio de MySQL. Se usa SMALLINT con una restricción CHECK
-- (0 = inactivo, 1 = activo) porque funciona igual en PostgreSQL y en
-- SQL Server sin alterar los datos de carga.
CREATE TABLE productos (
    id_producto       INT           NOT NULL,
    nombre_producto   VARCHAR(100)  NOT NULL,
    id_categoria      INT           NOT NULL,
    precio            DECIMAL(10,2) NOT NULL,
    stock             INT           NOT NULL DEFAULT 0,
    activo            SMALLINT      NOT NULL DEFAULT 1
);

-- Tabla 4: ventas ------------------------------------------------------
-- Tabla de hechos. Es la última en crearse porque depende de clientes y
-- de productos. Su grano es una línea de venta: un producto vendido a un
-- cliente en una fecha determinada.
-- 'precio_unitario' se almacena en la venta —y no se lee de productos—
-- porque es el precio EFECTIVAMENTE cobrado en ese momento. Si se leyera
-- de productos, una futura actualización de la lista de precios
-- reescribiría la historia y distorsionaría toda la serie de facturación.
CREATE TABLE ventas (
    id_venta          INT           NOT NULL,
    id_cliente        INT           NOT NULL,
    id_producto       INT           NOT NULL,
    cantidad          INT           NOT NULL,
    precio_unitario   DECIMAL(10,2) NOT NULL,
    fecha_venta       DATE          NOT NULL
);


-- =====================================================================
-- SECCIÓN 2 — RESTRICCIONES DE INTEGRIDAD
-- ---------------------------------------------------------------------
-- Las restricciones se declaran acá mediante ALTER TABLE (en lugar de
-- hacerlo dentro del CREATE TABLE) por dos motivos: quedan agrupadas y
-- legibles en un solo bloque, y todas reciben un NOMBRE explícito, de
-- modo que cuando el motor rechace una operación el mensaje de error
-- indique exactamente qué regla de negocio se violó.
-- Convención de nombres: pk_ / fk_ / uq_ / chk_
-- =====================================================================

-- ---------------------------------------------------------------------
-- 2.1 Claves primarias — identifican de forma única cada fila
-- ---------------------------------------------------------------------
ALTER TABLE categorias ADD CONSTRAINT pk_categorias PRIMARY KEY (id_categoria);
ALTER TABLE clientes   ADD CONSTRAINT pk_clientes   PRIMARY KEY (id_cliente);
ALTER TABLE productos  ADD CONSTRAINT pk_productos  PRIMARY KEY (id_producto);
ALTER TABLE ventas     ADD CONSTRAINT pk_ventas     PRIMARY KEY (id_venta);

-- ---------------------------------------------------------------------
-- 2.2 Claves foráneas — garantizan la integridad referencial
-- ON DELETE RESTRICT: impide borrar una categoría, un cliente o un
-- producto que tenga registros asociados. Es la política correcta para
-- datos históricos de ventas: el pasado no se borra en cascada.
-- ON UPDATE CASCADE: si alguna vez cambiara el valor de un id, la
-- modificación se propaga sola y no quedan referencias huérfanas.
-- ---------------------------------------------------------------------
ALTER TABLE productos
    ADD CONSTRAINT fk_productos_categoria
    FOREIGN KEY (id_categoria) REFERENCES categorias (id_categoria)
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE ventas
    ADD CONSTRAINT fk_ventas_cliente
    FOREIGN KEY (id_cliente) REFERENCES clientes (id_cliente)
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE ventas
    ADD CONSTRAINT fk_ventas_producto
    FOREIGN KEY (id_producto) REFERENCES productos (id_producto)
    ON DELETE RESTRICT ON UPDATE CASCADE;

-- ---------------------------------------------------------------------
-- 2.3 Restricción de unicidad
-- ---------------------------------------------------------------------
ALTER TABLE clientes ADD CONSTRAINT uq_clientes_email UNIQUE (email);

-- ---------------------------------------------------------------------
-- 2.4 Reglas de negocio (CHECK)
-- Las FK protegen las relaciones; los CHECK protegen los valores. Sin
-- ellos la base aceptaría una venta de cero unidades o un precio
-- negativo, y esos registros contaminarían después todos los KPIs.
-- ---------------------------------------------------------------------
ALTER TABLE productos ADD CONSTRAINT chk_productos_precio  CHECK (precio >= 0);
ALTER TABLE productos ADD CONSTRAINT chk_productos_stock   CHECK (stock >= 0);
ALTER TABLE productos ADD CONSTRAINT chk_productos_activo  CHECK (activo IN (0, 1));
ALTER TABLE ventas    ADD CONSTRAINT chk_ventas_cantidad   CHECK (cantidad > 0);
ALTER TABLE ventas    ADD CONSTRAINT chk_ventas_precio     CHECK (precio_unitario >= 0);

-- ---------------------------------------------------------------------
-- 2.5 Índices sobre las claves foráneas
-- PostgreSQL indexa automáticamente las claves primarias, pero NO las
-- foráneas. Como todos los JOIN del análisis pasan por estas columnas,
-- se indexan de forma explícita.
-- ---------------------------------------------------------------------
CREATE INDEX idx_productos_categoria ON productos (id_categoria);
CREATE INDEX idx_ventas_cliente      ON ventas (id_cliente);
CREATE INDEX idx_ventas_producto     ON ventas (id_producto);
CREATE INDEX idx_ventas_fecha        ON ventas (fecha_venta);


-- =====================================================================
-- SECCIÓN 3 — DML: CARGA INICIAL DE DATOS
-- ---------------------------------------------------------------------
-- El orden de carga es el DIRECTO de las dependencias, inverso al del
-- DROP: primero las tablas referenciadas (categorias, clientes), después
-- productos y por último ventas. Cargar ventas primero fallaría porque
-- sus claves foráneas no encontrarían a qué apuntar.
-- Se listan las columnas de forma explícita en cada INSERT: si mañana se
-- agrega una columna a la tabla, el script sigue funcionando igual.
-- =====================================================================

-- 3.1 categorias — 4 registros ----------------------------------------
INSERT INTO categorias (id_categoria, nombre_categoria, descripcion) VALUES
    (1, 'Computación',    'Laptops, PCs y monitores'),
    (2, 'Accesorios',     'Periféricos y complementos'),
    (3, 'Audio',          'Auriculares y parlantes'),
    (4, 'Almacenamiento', 'Discos y memorias');

-- 3.2 clientes — 5 registros ------------------------------------------
INSERT INTO clientes (id_cliente, nombre, email, ciudad, fecha_registro) VALUES
    (1, 'María López',   'maria@mail.com',  'Buenos Aires', '2024-01-05'),
    (2, 'Carlos Ruiz',   'carlos@mail.com', 'Córdoba',      '2024-01-10'),
    (3, 'Ana Gómez',     'ana@mail.com',    'Rosario',      '2024-02-01'),
    (4, 'Pedro Sanz',    'pedro@mail.com',  'Mendoza',      '2024-02-15'),
    (5, 'Laura Torres',  'laura@mail.com',  'Tucumán',      '2024-03-01');

-- 3.3 productos — 6 registros -----------------------------------------
INSERT INTO productos (id_producto, nombre_producto, id_categoria, precio, stock, activo) VALUES
    (1, 'Laptop Pro 15',      1, 1200.00, 15, 1),
    (2, 'Mouse Inalámbrico',  2,   28.00, 80, 1),
    (3, 'Monitor 4K 27"',     1,  450.00, 12, 1),
    (4, 'Auriculares BT Pro', 3,  120.00, 35, 1),
    (5, 'SSD Externo 1TB',    4,  130.00, 18, 1),
    (6, 'Teclado Mecánico',   2,   95.00, 40, 1);

-- 3.4 ventas — 10 registros -------------------------------------------
INSERT INTO ventas (id_venta, id_cliente, id_producto, cantidad, precio_unitario, fecha_venta) VALUES
    ( 1, 1, 1, 2, 1200.00, '2024-03-05'),
    ( 2, 2, 2, 5,   28.00, '2024-03-06'),
    ( 3, 3, 3, 1,  450.00, '2024-03-07'),
    ( 4, 1, 4, 2,  120.00, '2024-03-08'),
    ( 5, 4, 5, 3,  130.00, '2024-03-10'),
    ( 6, 2, 6, 4,   95.00, '2024-03-11'),
    ( 7, 5, 1, 1, 1200.00, '2024-03-12'),
    ( 8, 3, 2, 8,   28.00, '2024-03-13'),
    ( 9, 4, 4, 1,  120.00, '2024-03-14'),
    (10, 5, 3, 2,  450.00, '2024-03-15');


-- =====================================================================
-- SECCIÓN 4 — CONSULTAS DE VERIFICACIÓN
-- ---------------------------------------------------------------------
-- Ejecutar después de la carga para confirmar que la base quedó íntegra.
-- =====================================================================

-- 4.1 Contenido de cada tabla -----------------------------------------
SELECT * FROM categorias ORDER BY id_categoria;
SELECT * FROM clientes   ORDER BY id_cliente;
SELECT * FROM productos  ORDER BY id_producto;
SELECT * FROM ventas     ORDER BY id_venta;

-- 4.2 Recuento de filas esperado --------------------------------------
-- Resultado esperado: 4 categorías, 5 clientes, 6 productos, 10 ventas.
SELECT 'categorias' AS tabla, COUNT(*) AS filas FROM categorias
UNION ALL SELECT 'clientes',  COUNT(*) FROM clientes
UNION ALL SELECT 'productos', COUNT(*) FROM productos
UNION ALL SELECT 'ventas',    COUNT(*) FROM ventas;

-- 4.3 Control de integridad referencial --------------------------------
-- Ambas consultas deben devolver 0 filas huérfanas. Si devolvieran algo,
-- significaría que alguna FK no se aplicó correctamente.
SELECT COUNT(*) AS ventas_sin_cliente
FROM ventas v
LEFT JOIN clientes c ON v.id_cliente = c.id_cliente
WHERE c.id_cliente IS NULL;

SELECT COUNT(*) AS productos_sin_categoria
FROM productos p
LEFT JOIN categorias cat ON p.id_categoria = cat.id_categoria
WHERE cat.id_categoria IS NULL;

-- 4.4 Prueba de que el modelo responde preguntas de negocio ------------
-- (Los JOIN se ven en profundidad en el Módulo 5; se incluye una consulta
--  de muestra para demostrar que el esquema está correctamente conectado.)
SELECT
    cat.nombre_categoria                     AS categoria,
    COUNT(v.id_venta)                        AS operaciones,
    SUM(v.cantidad)                          AS unidades,
    SUM(v.cantidad * v.precio_unitario)      AS facturacion
FROM ventas v
JOIN productos  p   ON v.id_producto  = p.id_producto
JOIN categorias cat ON p.id_categoria = cat.id_categoria
GROUP BY cat.nombre_categoria
ORDER BY facturacion DESC;

-- =====================================================================
-- FIN DEL SCRIPT
-- =====================================================================

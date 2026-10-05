-- ══════════════════════════════════════════════════════════════════
-- RetailPro / Ventas_Tech_DB — Esquema y datos de prueba
-- Motor: PostgreSQL 13+
-- ══════════════════════════════════════════════════════════════════
-- Base del Checkpoint del Módulo 3, con dos ampliaciones:
--
--   1. Dimensiones descriptivas: se agregó la tabla territorios
--      (región / país / zona) y la columna segmento en clientes.
--      La consigna del Módulo 5 las pide explícitamente porque la
--      Consulta 1 va a ser la fuente de datos principal en Power BI,
--      y ahí hacen falta columnas para agrupar y para filtrar.
--      Ambas ya estaban previstas en el modelo del Módulo 2.
--
--   2. Datos de prueba ampliados a 6 meses (enero–junio 2024), con
--      dos clientes y dos productos deliberadamente SIN ventas, que
--      son los que aíslan las consultas 2 y 3.
-- ══════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS territorios;
DROP TABLE IF EXISTS categorias;

-- ── dimensiones ───────────────────────────────────────────────────
CREATE TABLE categorias (
    id_categoria      INT           PRIMARY KEY,
    nombre_categoria  VARCHAR(50)   NOT NULL,
    descripcion       VARCHAR(200)
);

CREATE TABLE territorios (
    id_territorio     INT           PRIMARY KEY,
    region            VARCHAR(50)   NOT NULL,
    pais              VARCHAR(50)   NOT NULL,
    zona              VARCHAR(50)   NOT NULL
);

CREATE TABLE clientes (
    id_cliente        INT           PRIMARY KEY,
    nombre            VARCHAR(100)  NOT NULL,
    email             VARCHAR(100)  UNIQUE,
    ciudad            VARCHAR(50),
    segmento          VARCHAR(30)   NOT NULL
                      CHECK (segmento IN ('Minorista','Mayorista','Corporativo')),
    id_territorio     INT           NOT NULL REFERENCES territorios (id_territorio),
    fecha_registro    DATE          NOT NULL
);

CREATE TABLE productos (
    id_producto       INT           PRIMARY KEY,
    nombre_producto   VARCHAR(100)  NOT NULL,
    id_categoria      INT           NOT NULL REFERENCES categorias (id_categoria),
    precio            DECIMAL(10,2) NOT NULL CHECK (precio >= 0),
    stock             INT           NOT NULL DEFAULT 0,
    activo            SMALLINT      NOT NULL DEFAULT 1 CHECK (activo IN (0,1))
);

-- ── tabla de hechos ───────────────────────────────────────────────
CREATE TABLE ventas (
    id_venta          INT           PRIMARY KEY,
    id_cliente        INT           NOT NULL REFERENCES clientes (id_cliente),
    id_producto       INT           NOT NULL REFERENCES productos (id_producto),
    cantidad          INT           NOT NULL CHECK (cantidad > 0),
    precio_unitario   DECIMAL(10,2) NOT NULL CHECK (precio_unitario >= 0),
    fecha_venta       DATE          NOT NULL
);

-- ══════════════════════════════════════════════════════════════════
-- CARGA DE DATOS
-- ══════════════════════════════════════════════════════════════════

INSERT INTO categorias (id_categoria, nombre_categoria, descripcion) VALUES
    (1, 'Computación',    'Laptops, PCs y monitores'),
    (2, 'Accesorios',     'Periféricos y complementos'),
    (3, 'Audio',          'Auriculares y parlantes'),
    (4, 'Almacenamiento', 'Discos y memorias');

INSERT INTO territorios (id_territorio, region, pais, zona) VALUES
    (1, 'Centro',  'Argentina', 'AMBA'),
    (2, 'Centro',  'Argentina', 'Córdoba'),
    (3, 'Litoral', 'Argentina', 'Santa Fe'),
    (4, 'Cuyo',    'Argentina', 'Mendoza'),
    (5, 'Norte',   'Argentina', 'NOA');

-- Clientes 6 y 7: registrados, todavía sin ninguna compra.
INSERT INTO clientes (id_cliente, nombre, email, ciudad, segmento, id_territorio, fecha_registro) VALUES
    (1, 'María López',     'maria@mail.com',  'Buenos Aires', 'Corporativo', 1, '2024-01-05'),
    (2, 'Carlos Ruiz',     'carlos@mail.com', 'Córdoba',      'Minorista',   2, '2024-01-10'),
    (3, 'Ana Gómez',       'ana@mail.com',    'Rosario',      'Mayorista',   3, '2024-02-01'),
    (4, 'Pedro Sanz',      'pedro@mail.com',  'Mendoza',      'Minorista',   4, '2024-02-15'),
    (5, 'Laura Torres',    'laura@mail.com',  'Tucumán',      'Corporativo', 5, '2024-03-01'),
    (6, 'Diego Fernández', 'diego@mail.com',  'Salta',        'Minorista',   5, '2024-04-02'),
    (7, 'Sofía Ramos',     'sofia@mail.com',  'La Plata',     'Mayorista',   1, '2024-05-20');

-- Productos 7 y 8: en catálogo, nunca vendidos.
INSERT INTO productos (id_producto, nombre_producto, id_categoria, precio, stock, activo) VALUES
    (1, 'Laptop Pro 15',       1, 1200.00, 15, 1),
    (2, 'Mouse Inalámbrico',   2,   28.00, 80, 1),
    (3, 'Monitor 4K 27"',      1,  450.00, 12, 1),
    (4, 'Auriculares BT Pro',  3,  120.00, 35, 1),
    (5, 'SSD Externo 1TB',     4,  130.00, 18, 1),
    (6, 'Teclado Mecánico',    2,   95.00, 40, 1),
    (7, 'Webcam HD 1080',      2,   60.00, 25, 1),
    (8, 'Parlante Bluetooth',  3,   85.00, 30, 1);

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
    (10, 5, 3, 2,  450.00, '2024-03-15'),
    (11, 1, 1, 1, 1200.00, '2024-01-08'),
    (12, 2, 2, 5,   28.00, '2024-01-15'),
    (13, 3, 6, 2,   95.00, '2024-01-22'),
    (14, 1, 3, 1,  450.00, '2024-01-29'),
    (15, 4, 4, 3,  120.00, '2024-02-05'),
    (16, 5, 2,10,   28.00, '2024-02-12'),
    (17, 2, 5, 2,  130.00, '2024-02-19'),
    (18, 3, 1, 1, 1200.00, '2024-02-26'),
    (19, 1, 2, 6,   28.00, '2024-04-03'),
    (20, 2, 3, 1,  450.00, '2024-04-10'),
    (21, 4, 6, 3,   95.00, '2024-04-17'),
    (22, 5, 5, 1,  130.00, '2024-04-24'),
    (23, 3, 1, 2, 1200.00, '2024-05-06'),
    (24, 1, 4, 4,  120.00, '2024-05-13'),
    (25, 2, 2, 7,   28.00, '2024-05-20'),
    (26, 4, 3, 2,  450.00, '2024-05-27'),
    (27, 5, 6, 2,   95.00, '2024-06-04'),
    (28, 3, 5, 3,  130.00, '2024-06-11'),
    (29, 1, 1, 1, 1200.00, '2024-06-18'),
    (30, 2, 4, 2,  120.00, '2024-06-25');

-- ============================================================
-- Proyecto: Food Store
--   Trabajo Práctico N.º 3 — Base de Datos 2 (UTN)
--   Motor: PostgreSQL 17
-- ============================================================
-- ADVERTENCIA: los DROP TABLE siguientes ELIMINAN las tablas con
-- todo su contenido, sin previo aviso ni posibilidad de deshacer.
-- Este script está pensado para aplicarse UNA SOLA VEZ, sobre una
-- base recién creada y VACÍA. Una vez ejecutada la carga masiva
-- (~670.000 filas), reejecutar este script destruye todos los datos
-- generados. Si hiciera falta volver a aplicarlo, se crea una base
-- nueva; no se reejecuta sobre una base ya poblada.
-- ============================================================

-- ------------------------------------------------------------
-- DROP TABLE — orden inverso al de creación (las tablas que tienen
-- FK hacia otras se eliminan antes que las referenciadas). El
-- CASCADE cubre referencias adicionales, pero el orden explícito
-- es la práctica correcta.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS detalle_pedido CASCADE; -- referencia a pedido y producto
DROP TABLE IF EXISTS pedido CASCADE;         -- referencia a usuario
DROP TABLE IF EXISTS producto CASCADE;       -- referencia a categoria
DROP TABLE IF EXISTS usuario CASCADE;        -- no referencia a otras tablas
DROP TABLE IF EXISTS categoria CASCADE;      -- no referencia a otras tablas

-- ------------------------------------------------------------
-- CATEGORIA
-- Entidad de catálogo. Se crea primero: es referenciada por producto.
-- ------------------------------------------------------------
CREATE TABLE categoria (
    -- PK autogenerada: id es la convención para toda clave primaria
    -- (BIGINT GENERATED ALWAYS AS IDENTITY, no editable por el usuario)
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- UNIQUE: evita duplicados (ej.: dos filas "Bebidas"). El índice
    -- implícito que genera es el único permitido en este TP (sección 5.3)
    nombre    VARCHAR(80)  NOT NULL UNIQUE,
    -- Baja lógica: FALSE = vigente, TRUE = discontinuada. Nunca se hace
    -- DELETE físico de una categoría para no perder el historial de los
    -- productos que la referenciaron
    eliminado BOOLEAN      NOT NULL DEFAULT FALSE
);

-- ------------------------------------------------------------
-- USUARIO
-- Registra las personas que realizan pedidos. Sin baja lógica: un
-- usuario es un hecho persistente del sistema; darlo de baja
-- distorsionaría el historial de pedidos asociados.
-- ------------------------------------------------------------
CREATE TABLE usuario (
    id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- PK autogenerada
    -- Sin UNIQUE en nombre: puede haber homónimos (personas con igual nombre)
    nombre VARCHAR(120) NOT NULL,
    -- UNIQUE: el email funciona como identificador natural único del
    -- usuario. Genera su índice implícito (único permitido, sección 5.3)
    email  VARCHAR(150) NOT NULL UNIQUE
);

-- ------------------------------------------------------------
-- PRODUCTO
-- Entidad de catálogo. Depende de categoria (FK).
-- ------------------------------------------------------------
CREATE TABLE producto (
    id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- PK autogenerada
    -- Sin UNIQUE en nombre: no se exige unicidad a nivel de esquema
    nombre   VARCHAR(120)       NOT NULL,
    -- precio de lista actual. CHECK(precio >= 0): impide precios negativos.
    -- NUMERIC(10,2) admite hasta 99.999.999,99 (precisión monetaria exacta)
    precio   NUMERIC(10,2)      NOT NULL CHECK (precio >= 0),
    -- Unidades disponibles. DEFAULT 0: un producto recién creado empieza con
    -- stock cero. CHECK(stock >= 0): impide valores negativos
    stock    INTEGER            NOT NULL DEFAULT 0 CHECK (stock >= 0),
    -- Baja lógica: FALSE = vigente, TRUE = discontinuado. Nunca DELETE
    -- físico, para no perder el historial de ventas del producto
    eliminado BOOLEAN           NOT NULL DEFAULT FALSE,
    -- FK a categoria. ON DELETE RESTRICT: impide eliminar físicamente una
    -- categoría si tiene productos asociados (vigentes o no); para dejar
    -- de ofrecerla se usa la baja lógica
    categoria_id BIGINT         NOT NULL REFERENCES categoria(id) ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- PEDIDO
-- Cabecera de un pedido. Depende de usuario (FK). Representa un hecho
-- ocurrido en el tiempo: no lleva baja lógica ni columna de estado
-- (el TP no modela el ciclo de vida del pedido).
-- ------------------------------------------------------------
CREATE TABLE pedido (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- PK autogenerada
    -- Marca temporal con zona horaria. DEFAULT now(): permite insertar sin
    -- especificar fecha (toma automáticamente el momento del registro)
    fecha     TIMESTAMPTZ      NOT NULL DEFAULT now(),
    -- FK a usuario. ON DELETE RESTRICT: impide eliminar físicamente un
    -- usuario que tenga pedidos registrados (preserva el historial)
    usuario_id BIGINT          NOT NULL REFERENCES usuario(id) ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- DETALLE_PEDIDO
-- Línea individual de un pedido. Depende de pedido y producto (FK).
-- Se crea última porque es la tabla que más referencias apunta.
-- ------------------------------------------------------------
CREATE TABLE detalle_pedido (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- PK autogenerada
    -- FK a pedido. ON DELETE CASCADE: si se elimina físicamente un pedido,
    -- sus líneas se eliminan en cascada (las líneas no tienen sentido
    -- sin su cabecera)
    pedido_id  BIGINT          NOT NULL REFERENCES pedido(id) ON DELETE CASCADE,
    -- FK a producto. ON DELETE RESTRICT: impide eliminar físicamente un
    -- producto que aparezca en algún detalle (preserva el historial)
    producto_id BIGINT         NOT NULL REFERENCES producto(id) ON DELETE RESTRICT,
    -- Unidades de esta línea. CHECK(cantidad > 0): exige al menos 1 unidad
    -- (es > 0, no >= 0, porque una línea con 0 unidades no tiene sentido)
    cantidad   INTEGER         NOT NULL CHECK (cantidad > 0),
    -- Precio del producto al momento de la compra (desnormalizado, ver
    -- sección 5.2 de la spec): se copia de producto.precio en ese instante
    -- y se preserva inmutable. CHECK(precio_unitario >= 0): impide negativos
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0),
    -- Constraint único compuesto: un producto aparece como máximo una vez
    -- por pedido. Genera el índice implícito (pedido_id, producto_id) que
    -- precisamente cubre las búsquedas por pedido_id (ver sección 7 de la spec)
    UNIQUE (pedido_id, producto_id)
);

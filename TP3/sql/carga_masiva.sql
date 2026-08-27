-- ============================================================
-- Proyecto: Food Store
--   Trabajo Práctico N.º 3 — Base de Datos 2 (UTN)
--   Motor: PostgreSQL 17
-- ============================================================
-- CARGA MASIVA — Parte 1 del TP3
--
-- Se pueblan las cinco tablas sobre la base bd2_tp3 (el esquema ya
-- está aplicado y las tablas están vacías; este script SOLO inserta).
--
-- Volúmenes que genera:
--   categoria      : 12 filas      (rubros realistas, todas con eliminado=FALSE)
--   usuario        : 20.000 filas
--   producto       : 50.000 filas  (distribuidos de forma pareja en 12 categorías)
--   pedido         : 200.000 filas
--   detalle_pedido : ~400.000 filas (1 a 3 líneas por pedido, promedio ~2)
--
-- Orden de inserción (respeta dependencias de FK):
--   1. categoria   (referenciada por producto)
--   2. usuario     (referenciada por pedido)
--   3. producto    (referencia categoria)
--   4. pedido      (referencia usuario)
--   5. detalle_pedido (referencia pedido y producto)
--
-- NOTAS:
--   * Ninguna PK se inserta explícitamente: todas son GENERATED ALWAYS
--     AS IDENTITY, las asigna el motor. Como los INSERT son deterministas
--     y en orden, los id quedan consecutivos (categoria 1-12, usuario
--     1-20000, producto 1-50000, pedido 1-200000). Las FK se resuelven
--     a partir de esos rangos generados; no se hardcodea ningún id.
--   * Este archivo NO incluye BEGIN/COMMIT (la transacción la maneja
--     quien ejecuta) ni CREATE INDEX ni ANALYZE (se corren aparte,
--     después de la carga).
-- ============================================================

-- ------------------------------------------------------------
-- 1) CATEGORIA  (12 filas)
--    Rubros realistas de un local de comidas. Todas quedan vigentes
--    (eliminado = FALSE). La PK la asigna el motor: al insertar 12
--    filas seguidas, quedan con id 1..12.
-- ------------------------------------------------------------
INSERT INTO categoria (nombre, eliminado)
SELECT
    (ARRAY[
        'Bebidas',
        'Lacteos',
        'Panificados',
        'Carnes',
        'Ensaladas',
        'Pastas',
        'Pizzas',
        'Postres',
        'Sandwiches',
        'Comida Vegana',
        'Menus Ejecutivos',
        'Minutas'
    ])[n],                       -- el índice n elige un rubro del arreglo (1..12)
    FALSE                        -- todas vigentes
FROM generate_series(1, 12) AS n;

-- ------------------------------------------------------------
-- 2) USUARIO  (20.000 filas)
--    nombre: genérico derivado del nº de fila.
--    email : UNIQUE. Se deriva del nº de fila (no de random()), de modo
--    que es único por construcción y estable al reejecutar.
--    Los id generados ocupan 1..20000.
-- ------------------------------------------------------------
INSERT INTO usuario (nombre, email)
SELECT
    'Usuario ' || n,                              -- nombre genérico por fila
    'usuario.' || n || '@foodstore.local'         -- email UNIQUE derivado de n
FROM generate_series(1, 20000) AS n;

-- ------------------------------------------------------------
-- 3) PRODUCTO  (50.000 filas)
--    categoria_id: reparto PAREJO entre las 12 categorías. Con n de 1 a
--    50000, `1 + mod(n-1, 12)` recorre cíclicamente 1..12 dando a cada
--    categoría 4166 o 4167 productos (diferencia de 1 = parejo).
--    precio : rango [500, 5000]. mod(n,4501) da 0..4500 -> 500..5000.
--    stock  : rango [0, 200].    mod(n,201)   da 0..200.
--    eliminado = FALSE (todos vigentes).
--    Los id generados ocupan 1..50000.
-- ------------------------------------------------------------
INSERT INTO producto (nombre, precio, stock, eliminado, categoria_id)
SELECT
    'Producto ' || n,                              -- nombre genérico por fila
    (500 + mod(n, 4501))::numeric(10,2),           -- precio: 500..5000
    mod(n, 201),                                   -- stock:  0..200
    FALSE,                                         -- vigente
    1 + mod(n - 1, 12)                             -- categoría: 1..12 parejo
FROM generate_series(1, 50000) AS n;

-- ------------------------------------------------------------
-- 4) PEDIDO  (200.000 filas)
--    usuario_id: distribución DESPAREJA pero determinista. El 70% de los
--    pedidos (mod(n,10)<7 -> 140.000) se reparte entre los primeros 2.000
--    usuarios ("clientes frecuentes", ~73 pedidos c/u); el 30% restante
--    (60.000) se reparte entre los 20.000. Ningún usuario queda en cero.
--    Se explica oralmente en una frase: "el 70% de los pedidos son de
--    clientes frecuentes". Función pura de n: estable al reejecutar.
--    fecha: repartida a lo largo de 2023 (365), 2024 (366) y 2025 (365).
--    Con mod(n-1, 1096) se recorre cíclicamente el total de días de los
--    tres años (365+366+365), de forma pareja entre años y entre días.
--    Fechas explícitas (sin now()): los rangos dan resultados estables
--    al reejecutar. Se suma un desfase horario para dar variedad al
--    TIMESTAMPTZ sin repetir todos a la misma hora.
--    Los id generados ocupan 1..200000.
-- ------------------------------------------------------------
INSERT INTO pedido (fecha, usuario_id)
SELECT
    TIMESTAMPTZ '2023-01-01'
        + make_interval(days => mod(n - 1, 1096))                -- día 0..1095 (3 años)
        + make_interval(secs => mod(n * 7919, 86400)),           -- hora variable (0..86399 s)
    CASE
        WHEN mod(n, 10) < 7 THEN 1 + mod(n, 2000)    -- 70%: clientes frecuentes (1..2000)
        ELSE 1 + mod(n, 20000)                       -- 30%: repartidos en los 20.000
    END
FROM generate_series(1, 200000) AS n;

-- ------------------------------------------------------------
-- 5) DETALLE_PEDIDO  (~400.000 filas)
--    Entre 1 y 3 líneas por pedido (promedio ~2). Se genera cruzando la
--    tabla pedido YA cargada con una serie de líneas 1..3, y se filtra
--    `l <= 1 + mod(p.id - 1, 3)` para que cada pedido reciba exactamente
--    1, 2 o 3 líneas de forma cíclica (p.id) :
--        p.id ≡ 1 mod 3 -> 1 línea ;  p.id ≡ 2 mod 3 -> 2 ;  p.id ≡ 0 -> 3
--    Promedio (1+2+3)/3 = 2 -> ~200.000 * 2 = ~400.000 líneas.
--    Correcto por construcción (no hace falta manejar bordes manuales).
--
--    producto_id — FÓRMULA DE UNICIDAD (la que se defiende oralmente):
--        producto_id = 1 + mod(p.id + (l - 1) * 16000, 50000)
--    Para un pedido fijo, las líneas difieren solo en (l-1) ∈ {0,1,2},
--    o sea en desplazamientos de 0, 16000 y 32000 posiciones.
--    Sumar un desplazamiento fijo y aplicar módulo es una ROTACIÓN del
--    catálogo: entradas distintas siempre dan salidas distintas. Dos
--    líneas del mismo pedido están separadas por 16000 o por 32000
--    posiciones, y como ninguno de esos dos números es múltiplo de
--    50000, los resultados nunca coinciden. Que el cálculo dé la vuelta
--    al módulo no afecta nada: la vuelta corre el catálogo, no lo pisa.
--    Dos líneas del mismo pedido jamás repiten producto: es una garantía
--    por construcción, no una probabilidad. Cumple UNIQUE(pedido_id, producto_id) sin ON
--    CONFLICT ni reintentos.
--
--    cantidad      : 1..5        (mod(...,5) -> 0..4, +1 -> 1..5)
--    precio_unitario: se LEE de producto.precio mediante un JOIN contra
--    la tabla producto, usando la misma fórmula de unicidad para elegir
--    la fila. No se recalcula con ninguna fórmula: el precio guardado en
--    la línea es, por construcción, el precio real del producto que la
--    línea referencia. Esto reproduce el flujo descripto en la spec
--    (sección 6, paso 3): el precio se copia del producto en el momento
--    de la venta y queda congelado en el detalle.
-- ------------------------------------------------------------
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT
    p.id,                                  -- FK al pedido (tomada de la tabla ya cargada)
    pr.id,                                 -- FK al producto elegido por la fórmula de unicidad
    1 + mod(p.id * 3 + l, 5),              -- cantidad: 1..5
    pr.precio                              -- precio LEIDO del producto, no recalculado
FROM pedido AS p
CROSS JOIN generate_series(1, 3) AS l
JOIN producto AS pr
  ON pr.id = 1 + mod(p.id + (l - 1) * 16000, 50000)  -- fórmula de unicidad
WHERE l <= 1 + mod(p.id - 1, 3);
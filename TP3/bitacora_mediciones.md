# Bitácora de mediciones — TP3 Parte 2

Base: `bd2_tp3` · PostgreSQL 17.11 · ANALYZE corrido tras la carga masiva.
Planes completos en `TP3/planes/`.

## Estado inicial (sin índices manuales)

| # | Consulta | Filas | De un total | Tiempo real |
|---|---|---|---|---|
| 01 | `pedido WHERE usuario_id = 1500` | 10 | 200.000 | 17,479 ms |
| 02 | `producto WHERE categoria_id = 3 AND eliminado = FALSE` | 4.167 | 50.000 | 7,928 ms |
| 03 | `pedido WHERE fecha >= '2025-01-01' AND fecha < '2026-01-01'` | 66.430 | 200.000 | 21,512 ms |
| 04 | `pedido WHERE EXTRACT(YEAR FROM fecha) = 2025` | 66.430 | 200.000 | 64,870 ms |

Las cuatro dan `Seq Scan`, como se esperaba sin índices.

## Hallazgo 1 — La distribución de pedidos por usuario no salió como se predijo

Al diseñar la carga se predijo que los usuarios 1 a 2000 tendrían ~73
pedidos cada uno. La medición real dio tres grupos, no dos:

- algunos usuarios del rango 1-2000 con 100 pedidos
- otros del mismo rango con ~10 (el usuario 1500 es uno de estos)
- los usuarios 2001-20000 con ~3 cada uno (54.000 pedidos en total)

Causa: la rama `mod(n,10) < 7` filtra por último dígito, y eso reparte
de forma no uniforme dentro del rango 1-2000.

No perjudica el trabajo: da tres grados de selectividad para comparar
con el mismo índice, en lugar de dos.

## Hallazgo 2 — `EXTRACT` no solo impide el índice: también rompe la estimación

Las consultas 03 y 04 responden la misma pregunta (pedidos de 2025) y
devuelven las mismas 66.430 filas, pero la 04 tarda tres veces más
(64,870 ms contra 21,512 ms), y eso sin que haya ningún índice todavía.

El motivo está en la estimación: la 04 estima `rows=1000` cuando el
resultado real son 66.430 filas — un error de factor 66. PostgreSQL
mantiene estadísticas sobre la columna `fecha`, no sobre
`EXTRACT(YEAR FROM fecha)`; al taparla con una función se queda sin
información y usa un valor por defecto.

Esa mala estimación tiene consecuencia visible en el plan: al creer que
eran 1.000 filas, el optimizador lanzó un worker paralelo
(`Workers Planned: 1`) para una consulta que devuelve 66.430. Eligió mal
la estrategia porque estimó mal.

Conclusión para la defensa: la sargability no es solo "poder usar el
índice". Aplicar una función sobre la columna filtrada también ciega al
optimizador.

## Índice 1 — `idx_pedido_usuario` sobre `pedido(usuario_id)`

`CREATE INDEX idx_pedido_usuario ON pedido(usuario_id);`

| | Antes | Después |
|---|---|---|
| Nodo | `Seq Scan` | `Bitmap Heap Scan` + `Bitmap Index Scan` |
| Cost estimado | 0.00..3774.00 | 4.51..104.41 |
| Tiempo real | 17,479 ms | 0,366 ms |
| Filas descartadas por filtro | 199.990 | — |

**Mejora: 47,8x**

El nodo elegido es `Bitmap Heap Scan`, no `Index Scan`: las 10 filas
están repartidas en 10 páginas distintas, así que el motor arma primero
un mapa de páginas candidatas y después las visita en orden físico, en
lugar de ir y volver al índice fila por fila. Es la estrategia
intermedia descripta en la clase.

Desaparece el `Rows Removed by Filter: 199990`: ya no se leen 200.000
filas para devolver 10.

## Índice 2 — `idx_producto_categoria` sobre `producto(categoria_id)`

`CREATE INDEX idx_producto_categoria ON producto(categoria_id);`

| | Antes | Después |
|---|---|---|
| Nodo | `Seq Scan` | `Bitmap Heap Scan` + `Bitmap Index Scan` |
| Cost estimado | 0.00..1093.00 | 48.78..569.18 |
| Tiempo real | 7,928 ms | 3,440 ms |
| Heap Blocks visitados | — | 468 |

**Mejora: 2,3x**

## Hallazgo 3 — La misma técnica da 47,8x en un caso y 2,3x en otro

Los dos índices son del mismo tipo (B-tree sobre una columna FK) y se
crearon igual. La diferencia de rendimiento no está en la técnica sino
en la selectividad del filtro:

| Índice | Filas devueltas | De un total | % de la tabla | Mejora |
|---|---|---|---|---|
| `idx_pedido_usuario` | 10 | 200.000 | 0,005% | 47,8x |
| `idx_producto_categoria` | 4.167 | 50.000 | 8,3% | 2,3x |

Un filtro que devuelve el 8% de la tabla obliga al motor a visitar 468
páginas para juntar las filas (`Heap Blocks: exact=468`), contra 10
páginas en el caso del usuario. El índice ayuda a encontrarlas, pero
hay que ir a buscarlas igual.

Conclusión: antes de crear un índice conviene preguntarse qué porcentaje
de la tabla devuelve el filtro. Es lo que decide si el índice va a
cambiar algo o no.

## Índice 3 — `idx_pedido_fecha` sobre `pedido(fecha)`

`CREATE INDEX idx_pedido_fecha ON pedido(fecha);`

Consulta: `pedido WHERE fecha >= '2025-01-01' AND fecha < '2026-01-01'`

| | Antes | Después |
|---|---|---|
| Nodo | `Seq Scan` | `Bitmap Heap Scan` + `Bitmap Index Scan` |
| Cost estimado | 0.00..4274.00 | 1417.81..3688.96 |
| Tiempo real | 21,512 ms | 15,716 ms |
| Heap Blocks visitados | — | 596 |

**Mejora: 1,4x**

Se esperaba que el optimizador pudiera descartar el índice, porque el
filtro devuelve un tercio de la tabla. No lo descartó: lo usó, pero la
ganancia es mínima.

El plan explica por qué: el `Bitmap Index Scan` tarda solo 5,763 ms en
armar el mapa de páginas, pero el tiempo total es 15,716 ms. Más de la
mitad del tiempo se va en visitar las 596 páginas donde están las
66.430 filas. El índice hace su trabajo rápido; lo caro es traer un
tercio de la tabla, y eso no lo evita ningún índice.

## Curva de selectividad — resultado de las tres mediciones

| Índice | Filas devueltas | % de la tabla | Mejora medida |
|---|---|---|---|
| `idx_pedido_usuario` | 10 de 200.000 | 0,005% | 47,8x |
| `idx_producto_categoria` | 4.167 de 50.000 | 8,3% | 2,3x |
| `idx_pedido_fecha` | 66.430 de 200.000 | 33,2% | 1,4x |

Tres índices B-tree creados con la misma sentencia, sobre el mismo
modelo, con resultados que van de 47,8x a 1,4x. La variable que explica
la diferencia es el porcentaje de la tabla que devuelve el filtro.

## Sargability — el índice existe pero la consulta no lo puede usar

Con `idx_pedido_fecha` ya creado, se volvió a medir la consulta 04, que
responde la misma pregunta que la 03 (pedidos de 2025) pero escrita con
`EXTRACT(YEAR FROM fecha) = 2025`.

| Consulta | Nodo | Cost estimado | Tiempo real |
|---|---|---|---|
| `fecha >= '2025-01-01' AND fecha < '2026-01-01'` | `Bitmap Heap Scan` | 1417.81..3688.96 | 15,716 ms |
| `EXTRACT(YEAR FROM fecha) = 2025` | `Parallel Seq Scan` | 1000.00..4138.71 | 74,833 ms |

**Diferencia: 4,8x, con el mismo índice disponible para ambas.**

El plan de la versión con `EXTRACT` es idéntico al que daba antes de que
el índice existiera: mismo nodo, mismo cost, misma estimación errada de
`rows=1000`. El optimizador ni siquiera consideró el índice.

Motivo: el índice está construido sobre los valores de la columna
`fecha`. `EXTRACT(YEAR FROM fecha)` es otra cosa — un número calculado a
partir de ella — y no hay ningún índice sobre esa expresión. La función
"tapa" la columna y deja al índice fuera de juego.

Esta es la técnica de reescritura de la clase: la mejora no vino de
crear nada, sino de reescribir la condición para que pudiera resolverse
con un índice ya existente.
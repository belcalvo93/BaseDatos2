# AGENTS.md — Base de Datos 2

## Proyecto

TP integrador Food Store — materia Base de Datos 2, Tecnicatura Universitaria en Programación (UTN). Contexto académico: todo SQL debe ser defendible oralmente.

## Stack

- PostgreSQL 17.11 sobre Windows 11
- Terminal: Git Bash (`psql`, `createdb`, `pg_dump`)
- Editor: Visual Studio Code
- Sin framework de aplicación — scripts SQL puros

## Bases de datos

Las bases del TP2:

| Base | Rol |
|------|------|
| `bd2_proyecto` | Plantilla. **Nunca modificar.** |
| `bd2_trabajo` | Copia de trabajo. Sobre ella se ejecutan todos los scripts del TP2. |

Recrear la copia cuando haga falta:

```bash
dropdb -U postgres bd2_trabajo
createdb -U postgres -T bd2_proyecto bd2_trabajo
```

El TP3 va a necesitar sus propias bases, basadas en el esquema de cátedra (ver sección 6).

## Protocolo de seguridad

**Todo script** que escriba en la base debe seguir este orden:

1. **Respaldo** antes de cambios estructurales: `pg_dump -U postgres -F c -f "db/backups/bd2_trabajo_YYYYMMDD.dump" bd2_trabajo`
2. **Transacción con ROLLBACK** primero — inspeccionar la salida, y recién después repetir con COMMIT
3. **Verificar `SELECT current_database();`** antes de cualquier ejecución
4. **Leer cada línea** del script generado — si no se puede explicar, no se ejecuta
5. **Verificar en el motor** — no confiar en el reporte del agente sobre lo que hizo

Protocolo completo: `TP2/protocolo_seguridad.md`

## Convenciones SQL (esquema propio)

Convenciones del esquema usado en TP1 y TP2:

- Tablas y columnas: `snake_case` singular (`detalle_pedido`, no `detallePedidos`)
- PKs: `id_<tabla>` (`BIGINT GENERATED ALWAYS AS IDENTITY`)
- FKs: `id_<tabla_referenciada>`
- Índices: `idx_<tabla>_<columna(s)>`
- ENUMs: tipo en minúsculas (`forma_pago_enum`), valores en mayúsculas (`'EFECTIVO'`)
- Baja lógica: `activo BOOLEAN NOT NULL DEFAULT TRUE` — nunca DELETE físico en `categoria` ni `producto`
- `ON DELETE RESTRICT` en la mayoría de las FKs; `CASCADE` solo en `detalle_pedido.id_pedido`
- `precio_unitario` en `detalle_pedido` es un precio histórico congelado (R4), independiente de `producto.precio`
- Scripts idempotentes: `DROP … IF EXISTS … CASCADE` antes de `CREATE`

## Esquema de cátedra (TP3)

El TP3 usa el esquema de Food Store de la cátedra, que tiene nombres distintos a los del proyecto propio:

| Nuestro esquema (TP1/TP2) | Esquema de cátedra (TP3) |
|---|---|
| `activo` | `eliminado` |
| `id_cliente` | `usuario_id` |
| `id_categoria` | `categoria_id` |

Regla dura: **no mezclar convenciones entre TPs**. Cada TP respeta las naming conventions de su propio esquema. Los scripts del TP3 se escriben contra las tablas de cátedra, no contra las del TP1/TP2.

## Estructura de archivos

```
TP1/
├── Calvo_Belen_TP1.pdf      — informe del TP1
├── Diagrama ER.png           — diagrama entidad-relación
└── schema.sql                — DDL original

TP2/
├── protocolo_seguridad.md    — protocolo de seguridad (extenso)
├── spec_restricciones.md     — spec de las reglas de integridad
├── sql/
│   ├── schema.sql            — DDL del esquema (idéntico a TP1)
│   ├── datos.sql             — carga inicial
│   ├── restricciones.sql     — funciones y triggers de integridad
│   └── pruebas_restricciones.sql — casos de prueba (BEGIN/ROLLBACK)
├── informe_concurrencia.md   — informe de concurrencia
├── ejercicio_lectura_critica.md — análisis de scripts peligrosos
└── duia/                     — declaraciones de uso de IA por parte

TP3/                          — optimización de consultas (previsto, hoy vacío)
                              — carga masiva con generate_series
                              — EXPLAIN ANALYZE e índices

db/backups/                   — respaldos .dump (gitignored)
.kiro/steering/               — steering docs del proyecto (database.md, security-policies.md)
```

## Cuidados

- `EXPLAIN ANALYZE` sobre INSERT, UPDATE o DELETE **ejecuta la sentencia**, no solo la planifica — siempre envolver en una transacción
- `UPDATE` o `DELETE` sin `WHERE` afecta todas las filas — verificar el WHERE antes de ejecutar
- La conexión de DBeaver debe cerrarse antes de `createdb -T` (bloqueo de plantilla)
- Los respaldos (`db/backups/`) están gitignored — no commitearlos
- Los archivos `*.dump` y `*.backup` tampoco se commitean

## Seguridad

Respetar siempre las normas definidas en `.kiro/steering/security-policies.md`.
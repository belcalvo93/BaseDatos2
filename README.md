# Base de Datos II — Tecnicatura Universitaria en Programación (UTN)

Repositorio de trabajo de la materia. Proyecto integrador: Food Store.

## Estructura

| Carpeta | Contenido |
|---|---|
| `TP1/` | Modelo ER, normalización y DDL (Base de Datos I) |
| `TP2/` | Integridad, transacciones y concurrencia |
| `TP3/` | Optimización de consultas: EXPLAIN, índices |
| `db/` | Scripts de base y respaldos |
| `docs/` | Material de apoyo y diagramas |
| `.kiro/` | Steering docs y specs de Kiro |

## Entorno

- PostgreSQL 17.11 sobre Windows 11
- Git Bash (psql, createdb, pg_dump)
- Visual Studio Code
- OpenCode (Big Pickle / OpenCode Zen) y Kiro

## Protocolo de seguridad

Todo script que toque la base se aplica sobre una copia, dentro de una
transacción, y con respaldo previo si es un cambio estructural. El detalle
está en `TP2/protocolo_seguridad.md`.
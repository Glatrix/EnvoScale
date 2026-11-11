# `envo.db`

> **Status:** Not started. Planned for **Beyond**. Tier when it lands: Experimental.

An embedded transactional storage engine (B-tree + WAL), with a query layer later.

## Simple door

```envo
var db = db.Open("app.db")?;
```

## Full-control door

Page size, durability and locking control; raw B-tree access.

## Ports used

FileSystem

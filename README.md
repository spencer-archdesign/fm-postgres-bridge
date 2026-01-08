# FileMaker → PostgreSQL Reporting Bridge

A pragmatic data replication and analytics pipeline that mirrors operational data from a legacy FileMaker system into PostgreSQL for reporting, analysis, and architectural learning.

---

## Overview

This project implements a **one-way synchronization bridge** between a production FileMaker database and a PostgreSQL analytics database.

FileMaker remains the **system of record** for day-to-day operations, while PostgreSQL serves as a **reporting, querying, and learning environment** where relational modeling, SQL analytics, and data engineering patterns can be explored without disrupting production workflows.

The primary goals are:
- Enable Filemaker to PostgreSQL relational data modeling in a production system
- Enable advanced reporting and analytics that are difficult in FileMaker
- Begin long-term implementation of database migration away from Filemaker to PostgreSQL via pragmatic system integration

---

## Why This Exists

Many long-lived operational systems (especially in SMB environments) were built in tools like FileMaker that excel at rapid application development but become limiting for:
- complex reporting
- historical analysis
- cross-entity aggregation
- performance-sensitive queries

Rather than attempting a risky full migration, this project demonstrates a **low-risk hybrid approach**:
- Keep the operational system stable
- Replicate data outward for analytics
- Allow both systems to evolve independently

This mirrors how real organizations incrementally modernize legacy systems.

---

## High-Level Architecture

**Source of truth**
- FileMaker Server (operational system)

**Data movement**
- FileMaker scripts push changed records as JSON
- A lightweight sync service performs idempotent upserts

**Analytics layer**
- PostgreSQL stores replicated data
- SQL views and marts support reporting and analysis

**Optional**
- Read-only views may be exposed back to FileMaker via ODBC
```text
FileMaker Server
│
│  (JSON payloads / scheduled sync)
▼
Sync Service (API)
│
│  INSERT / UPSERT
▼
PostgreSQL
├── raw_* tables (mirrored data)
├── views (cleaned / joined)
└── marts (analytics-friendly reporting)
```
---

## Data Modeling Strategy

The database is organized into logical layers:

### Raw Layer (`raw_*`)
- Mirrors FileMaker tables closely
- Preserves UUID primary keys
- Minimal transformation
- Includes metadata:
  - `fm_updated_at`
  - `synced_at`
  - `is_deleted`

### Staging / Views
- Type normalization
- Relationship cleanup
- Business logic expressed in SQL

### Analytics / Marts
- Reporting-friendly structures
- Pre-joined datasets
- Time-series and aggregation-ready

This separation allows learning and experimentation without destabilizing ingestion.

---

## Repository Structure

```text
fm-postgres-bridge/
├── README.md          # Project overview and architecture
├── docs/              # Design notes and decisions
├── sql/               # Schemas, views, and marts
├── app/               # Sync service (added later)
└── docker/            # Local infrastructure (optional)
```
---

## What This Is (and Is Not)

**This is:**
- A reporting bridge and proof of concept
- A demonstration of incremental modernization
- A portfolio example of real-world system integration

**This is not:**
- A full FileMaker replacement
- A real-time transactional system
- A generic ETL framework

---

## Current Status

- PostgreSQL 17 initialized locally
- Git repository initialized and pushed
- Project structure established
- Ready to begin schema design and data replication

---

## Future Work

Planned additions include:
- Initial `raw_projects`, `raw_properties`, and `raw_invoices` schemas
- Sync service implementation
- Delete tracking via tombstone records
- Analytics views (AR aging, pipeline status, revenue trends)
- Optional FileMaker read-only dashboards

---

## License

This project is provided for educational and portfolio purposes.

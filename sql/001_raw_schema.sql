-- sql/001_raw_schema.sql
-- Raw landing zone for FileMaker → PostgreSQL bridge
-- Principle: capture source records losslessly (jsonb payload) + minimal metadata for auditing & incremental loads.

BEGIN;

-- Extensions (optional; keep minimal)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Schemas
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS meta;

-- ----------------------------
-- META: ingestion run tracking
-- ----------------------------
CREATE TABLE IF NOT EXISTS meta.ingestion_run (
  run_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_system text NOT NULL DEFAULT 'filemaker',
  started_at    timestamptz NOT NULL DEFAULT now(),
  finished_at   timestamptz,
  status        text NOT NULL DEFAULT 'running', -- running|success|failed
  notes         text
);

-- One row per table per run (optional but useful)
CREATE TABLE IF NOT EXISTS meta.ingestion_table_run (
  run_id        uuid NOT NULL REFERENCES meta.ingestion_run(run_id) ON DELETE CASCADE,
  source_table  text NOT NULL,
  extracted_at  timestamptz NOT NULL DEFAULT now(),
  row_count     integer,
  status        text NOT NULL DEFAULT 'running', -- running|success|failed
  error_message text,
  PRIMARY KEY (run_id, source_table)
);

-- Checkpointing for incremental loads (keep generic; you can refine later)
CREATE TABLE IF NOT EXISTS meta.ingestion_checkpoint (
  source_table       text PRIMARY KEY,
  last_source_pk     text,          -- last processed PK (string to be FM-friendly)
  last_modified_at   timestamptz,    -- if source exposes a modified timestamp
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS meta.ingestion_error (
  error_id     bigserial PRIMARY KEY,
  run_id       uuid REFERENCES meta.ingestion_run(run_id) ON DELETE SET NULL,
  source_table text NOT NULL,
  source_pk    text,
  error_at     timestamptz NOT NULL DEFAULT now(),
  error        text NOT NULL,
  payload      jsonb
);

-- ----------------------------
-- RAW: generic pattern tables
-- ----------------------------
-- Generic raw record table (one table per source_table is often nicer,
-- but starting with a single landing table is fine for early learning.)
CREATE TABLE IF NOT EXISTS raw.record (
  raw_id        bigserial PRIMARY KEY,
  batch_id      uuid NOT NULL, -- tie to a run_id or separate batch identifier
  source_system text NOT NULL DEFAULT 'filemaker',
  source_table  text NOT NULL,
  source_pk     text NOT NULL,
  extracted_at  timestamptz NOT NULL,
  loaded_at     timestamptz NOT NULL DEFAULT now(),
  source_hash   text,
  payload       jsonb NOT NULL
);

-- Prevent accidental duplicates per batch
CREATE UNIQUE INDEX IF NOT EXISTS ux_raw_record_batch_table_pk
  ON raw.record (batch_id, source_table, source_pk);

-- Fast lookup for latest version of a record
CREATE INDEX IF NOT EXISTS ix_raw_record_table_pk_loaded
  ON raw.record (source_table, source_pk, loaded_at DESC);

-- Querying/filtering helpers
CREATE INDEX IF NOT EXISTS ix_raw_record_table_extracted
  ON raw.record (source_table, extracted_at DESC);

-- Latest version of each source record (per table + pk)
CREATE OR REPLACE VIEW raw.latest_record AS
SELECT DISTINCT ON (source_table, source_pk)
  raw_id,
  batch_id,
  source_system,
  source_table,
  source_pk,
  extracted_at,
  loaded_at,
  source_hash,
  payload
FROM raw.record
ORDER BY source_table, source_pk, extracted_at DESC, loaded_at DESC, raw_id DESC;

COMMIT;
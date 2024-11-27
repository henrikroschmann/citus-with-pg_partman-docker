-- -- wrap in transaction to ensure Docker flag always visible
BEGIN;

CREATE SCHEMA partman;

CREATE EXTENSION pg_partman WITH SCHEMA partman;

CREATE EXTENSION citus;

CREATE EXTENSION citext;

CREATE EXTENSION hstore;

UPDATE pg_dist_node_metadata
SET
    metadata = jsonb_insert(metadata, '{docker}', 'true');

COMMIT;

\c postgres

BEGIN;

CREATE EXTENSION pg_cron;

COMMIT;

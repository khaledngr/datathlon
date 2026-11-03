# snowflake/ · SQL run inside Snowflake

| Folder | What | Build step |
| --- | --- | --- |
| `setup/` | One-time account setup: team users (`00_team_users.sql`, done 2 Nov) | 0 |
| `stages/` | Shared stage `LANDING` on the bucket + `NDJSON` format (`01`), tills `COPY INTO` ✅ (`02`); stock and API files next | 6, 7, 7b |
| `tasks/` | Snowflake Tasks: 06:00 root task → COPY INTO → MERGE → dbt build → gold, retries, finalizer | 10 |

Run a file as the service user: `.venv/bin/python snowflake/run_sql.py snowflake/stages/02_tills.sql`

Account `NVTLKDO-RP44213`, region `GCP_EUROPE_WEST3`. Objects that Terraform can manage (database, warehouses, roles) go in `terraform/`, not here.

Reused from: TD 2 SQL scripts, resource pack `06-orchestration-and-docker/snowflake-tasks/daily_pipeline_tasks.sql`.

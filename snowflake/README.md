# snowflake/ · SQL run inside Snowflake

| Folder | What | Build step |
| --- | --- | --- |
| `setup/` | One-time account setup: team users (`00`), resource monitor (`01`), access test allowed / denied (`02`), cost report as ACCOUNTADMIN (`03`), budgets (`04`), governance demo: masking, tags, showback (`05`), data quality monitors and alert (`06`), key pair generator (`gen_key.py`) | 0–3 |
| `stages/` | Shared stage `LANDING` on the bucket + `NDJSON` format (`01`), `COPY INTO` for tills (`02`), stock with control-file reconciliation (`03`), API files (`04`) | 6, 7, 7b |
| `tasks/` | Daily task graph in schema `OPS` (`01`): 06:00 → COPY INTO tills / stock / API + checks that fail the run → `EXECUTE DBT PROJECT` build → finalizer (run log `OPS.PIPELINE_RUNS`, failure e-mail); evidence queries (`02`) | 10 |

Run a file as the service user: `.venv/bin/python snowflake/run_sql.py snowflake/stages/02_tills.sql`

Step 10 order (after `terraform apply`): `.venv/bin/python dbt/deploy_to_snowflake.py` (the dbt project the task runs), then `snowflake/run_sql.py snowflake/tasks/01_daily_pipeline.sql` (re-run safe), then fill `OPS.ALERT_RECIPIENTS` once. Run the graph now: `EXECUTE TASK DATATHLON.OPS.T_START;` after a failure inside Snowflake is fixed: `EXECUTE TASK DATATHLON.OPS.T_START RETRY LAST;` (restarts from the failed task); after a missed morning job: `EXECUTE TASK DATATHLON.OPS.T_START;` (the new files need the COPY tasks again). Evidence: `snowflake/tasks/02_task_history.sql`.

Account `NVTLKDO-RP44213`, region `GCP_EUROPE_WEST3`. Objects that Terraform can manage (database, warehouses, roles) go in `terraform/`, not here.

Reused from: TD 2 SQL scripts, resource pack `06-orchestration-and-docker/snowflake-tasks/daily_pipeline_tasks.sql`.

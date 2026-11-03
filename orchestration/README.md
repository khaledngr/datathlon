# orchestration/ · who starts what every morning (step 10, D-041)

| When (Paris) | Where | What | File |
| --- | --- | --- | --- |
| 05:30 | Laptop: **cron → Docker container** | web orders up to yesterday → Postgres → BRONZE (MERGE + reconciliation); till, API and stock files → GCS | `morning_job.sh` → image `datathlon-morning-job:1.0.0` (`Dockerfile`, `morning_job.py`) |
| 06:00 | **Snowflake Tasks** | COPY INTO tills / stock / API, stock reconciliation and web check (fail = run stops), `dbt build` in Snowflake, finalizer log + failure e-mail | [snowflake/tasks/01_daily_pipeline.sql](../snowflake/tasks/01_daily_pipeline.sql) |

Snowflake cannot reach the laptop's Postgres nor run the simulators, so they run in the container; everything that can run where the data is (loads, checks, dbt) runs in Snowflake. In a real company the container would run on a scheduler server or a cloud job (Cloud Run job + Cloud Scheduler); cron plays that part on our laptop.

## Set up once (on the laptop that runs the job)

```bash
docker compose --env-file .env -f sources/postgres/docker-compose.yml up -d --wait
.venv/bin/python sources/postgres/generate_orders.py --init   # only on an EMPTY database (deterministic history)
docker build -f orchestration/Dockerfile -t datathlon-morning-job:1.0.0 .
orchestration/morning_job.sh --check                          # connections only: Postgres, Snowflake, GCS
# macOS: cron may not read ~/Documents. Once, by hand: System Settings > Privacy & Security > Full Disk Access >
# "+" > Cmd+Shift+G > /usr/sbin/cron. Without it cron mails "Operation not permitted" (tested 3 Nov).
(crontab -l 2>/dev/null; echo '30 5 * * * "'"$PWD"'/orchestration/morning_job.sh"') | crontab -
```

Snowflake side: `dbt/deploy_to_snowflake.py`, then `snowflake/run_sql.py snowflake/tasks/01_daily_pipeline.sql` (see [snowflake/README](../snowflake/README.md)).

## Run, watch, stop

```bash
orchestration/morning_job.sh                    # the daily run, by hand (safe to run twice: adds nothing)
tail -50 logs/morning_job.log                   # what the last runs did
crontab -l                                      # the schedule
crontab -l | grep -v morning_job.sh | crontab - # remove the schedule
```

## Rules

- **Only one laptop runs the cron** (Robin's): two laptops would both write the same days. The data is deterministic, so file names and contents are identical, and COPY INTO / MERGE never count twice, but one producer is simpler to explain and to debug.
- **The laptop must be awake at 05:30** with Docker Desktop installed (the script starts it if it is closed). If the job did not run, the Snowflake task `T_CHECK_WEB` fails at 06:00 and the team gets an e-mail: run `orchestration/morning_job.sh` by hand, then `EXECUTE TASK DATATHLON.OPS.T_START`.
- **No secret in the image:** settings come from `.env` at `docker run`, the Snowflake key and the Google sign-in are mounted read-only (`.dockerignore` keeps `.env`, keys and data out of the build).
- **Never `generate_orders.py --init` from the job:** it would reset the web shop (handover trap). The job only adds the missing days with `--next-day`.

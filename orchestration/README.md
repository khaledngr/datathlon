# orchestration/ · who starts what every morning (step 10, D-043, D-044)

| When (Paris) | Where | What | File |
| --- | --- | --- | --- |
| 05:30 | Google Cloud: **Cloud Scheduler → Cloud Run job** `datathlon-morning-job` | web orders up to yesterday → Postgres (Cloud SQL) → BRONZE (MERGE + reconciliation); till, API and stock files → GCS | image `morning-job` in Artifact Registry (`Dockerfile`, `morning_job.py`), declared in [terraform/morning_job.tf](../terraform/morning_job.tf) |
| 06:00 | **Snowflake Tasks** | COPY INTO tills / stock / API, stock reconciliation and web check (fail = run stops), `dbt build` in Snowflake, finalizer log + failure e-mail | [snowflake/tasks/01_daily_pipeline.sql](../snowflake/tasks/01_daily_pipeline.sql) |

Snowflake cannot run the simulators nor reach a Postgres outside, so they run in the container; everything that can run where the data is (loads, checks, dbt) runs in Snowflake. The container runs on Cloud Run, not on a laptop: nobody's computer has to be on at 05:30 (D-044).

**Secrets:** none in the image nor in Git. The job runs as the service account `datathlon-morning-job` (Google sign-in, no key file); the Postgres password and the Snowflake private key of `DATATHLON_PIPELINE` come from Secret Manager; Cloud SQL is reached through the Cloud SQL connector (IAM), no open IP.

## Deploy a new version of the job

```bash
orchestration/push_image.sh 1.1.1      # build for linux/amd64 and push to Artifact Registry
# then set morning_job_image_tag = "1.1.1" in terraform/variables.tf, and: cd terraform && terraform apply
```

## Set up once (done 3 Nov)

1. `terraform apply` creates Cloud SQL, Artifact Registry, the secrets, the service accounts, the job and the schedule.
2. The Snowflake private key goes into Secret Manager by hand (its public half is `terraform/keys/datathlon_pipeline_cloud.pub`), see [docs/MANUAL_STEPS.md](../docs/MANUAL_STEPS.md).
3. The empty Cloud SQL database is filled once: `gcloud run jobs execute datathlon-morning-job --region europe-west3 --args=--init-db --wait`. `--init-db` refuses a database that already has orders: it never wipes data.

## Run, watch, stop

```bash
gcloud run jobs execute datathlon-morning-job --region europe-west3 --wait                 # the daily run, by hand (safe twice)
gcloud run jobs execute datathlon-morning-job --region europe-west3 --args=--check --wait  # connections only
gcloud run jobs executions list --job datathlon-morning-job --region europe-west3          # past runs, success or failure
gcloud scheduler jobs pause datathlon-morning-job --location europe-west3                   # stop the schedule (resume: resume)
```

Logs: Google Cloud console → Cloud Run → Jobs → `datathlon-morning-job` → Logs.

## Rules

- **One producer per day:** only the Cloud Run job writes the daily data. The old laptop cron (`morning_job.sh`) is removed; the script stays for a local test against the Docker Postgres, never on a schedule.
- **If the job fails or does not run,** the Snowflake task `T_CHECK_WEB` fails at 06:00 and the team gets an e-mail: run the job by hand (above), then `EXECUTE TASK DATATHLON.OPS.T_START;` (the whole graph: the new files must be loaded by the COPY tasks; `RETRY LAST` would only re-run the check and dbt). Seen for real on 4 Nov (laptop off, before the move to Cloud Run): e-mail at 06:00, job + `EXECUTE TASK` at 10:00, green.
- **Never `generate_orders.py --init` in the daily run:** it would reset the web shop (handover trap). The job only adds the missing days with `--next-day`; `--init-db` is for a new empty database only.

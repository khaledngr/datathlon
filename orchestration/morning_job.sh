#!/bin/bash
# Datathlon · run the morning job image on a LAPTOP, against the local Docker Postgres (step 10, D-043).
# Since D-044 the daily run is the Cloud Run job (Cloud Scheduler 05:30): this script is for local tests only,
# never on a schedule (one producer per day). It writes to the same BRONZE and bucket: use it on a dev setup.
# By hand: orchestration/morning_job.sh          (a run)
#          orchestration/morning_job.sh --check  (connections only, writes nothing)
# Output goes to logs/morning_job.log (git-ignored).
set -euo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"   # cron starts with an almost empty PATH
repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"
mkdir -p logs
exec >> logs/morning_job.log 2>&1
echo "===== $(date '+%Y-%m-%d %H:%M:%S %Z') morning_job.sh $*"

set -a; source .env; set +a
image="datathlon-morning-job:1.0.0"

# Docker Desktop must run (it may be closed after a restart): start it and wait up to 2 minutes
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running: starting Docker Desktop"
    open -a Docker
    for _ in $(seq 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
fi

# The web shop database (Postgres in Docker, step 4): start it if it is stopped, wait until it is healthy
docker compose --env-file .env -f sources/postgres/docker-compose.yml up -d --wait

# The job itself, in its container. Settings from .env; the Snowflake key and the Google sign-in are mounted read-only.
docker run --rm --name datathlon-morning-job \
    --env-file .env \
    -e PGHOST=host.docker.internal \
    -e PIPELINE_PRIVATE_KEY_PATH=/secrets/snowflake_key.p8 \
    -e GOOGLE_APPLICATION_CREDENTIALS=/secrets/gcp_adc.json \
    -v "$PIPELINE_PRIVATE_KEY_PATH:/secrets/snowflake_key.p8:ro" \
    -v "$HOME/.config/gcloud/application_default_credentials.json:/secrets/gcp_adc.json:ro" \
    "$image" "$@"
echo "===== $(date '+%Y-%m-%d %H:%M:%S %Z') done"

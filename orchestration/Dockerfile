# Datathlon · the morning job image (step 10, D-041, D-042), adapted from the resource pack
# 06-orchestration-and-docker/docker/python-ingest-job. Built and pushed to Artifact Registry by
# orchestration/push_image.sh; Cloud Run runs it every morning (terraform/morning_job.tf).
# No secret inside: on Cloud Run the settings are environment variables, the Postgres password and the Snowflake key
# come from Secret Manager, Google sign-in is the job's service account. On a laptop: orchestration/morning_job.sh.
FROM python:3.12.7-slim

# Default for a laptop run (host.docker.internal = the laptop, where the local Postgres listens); Cloud Run sets PGHOST
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PGHOST=host.docker.internal

WORKDIR /app

COPY orchestration/requirements.txt orchestration/requirements.txt
RUN pip install -r orchestration/requirements.txt

# Only the jobs and the shared catalogue: no .env, no key, no data (see .dockerignore)
COPY sources/ sources/
COPY ingestion/ ingestion/
COPY orchestration/morning_job.py orchestration/

RUN useradd --create-home --uid 1000 datathlon && mkdir -p data/landing && chown -R datathlon data
USER datathlon

ENTRYPOINT ["python", "orchestration/morning_job.py"]

# Datathlon · the morning job image (step 10, D-041), adapted from the resource pack
# 06-orchestration-and-docker/docker/python-ingest-job. Build from the repo root:
#   docker build -f orchestration/Dockerfile -t datathlon-morning-job:1.0.0 .
# No secret inside: the .env settings, the Snowflake key and the Google sign-in are given at `docker run`
# (orchestration/morning_job.sh), read-only.
FROM python:3.12.7-slim

# host.docker.internal = the laptop that runs Docker: that is where Postgres (port 5433) listens
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

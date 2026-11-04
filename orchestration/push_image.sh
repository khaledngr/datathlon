#!/bin/bash
# Datathlon · build the morning job image and push it to Artifact Registry (step 10, D-042). From the repo root:
#   orchestration/push_image.sh 1.1.0
# Then set the same tag in terraform (variable morning_job_image_tag) and `terraform apply`: Cloud Run runs that tag.
# linux/amd64: Cloud Run runs Intel machines, our Macs are ARM. Signs in with the Google ADC login (no key file).
set -euo pipefail
tag="${1:?usage: orchestration/push_image.sh <tag, e.g. 1.1.0>}"
cd "$(dirname "$0")/.."
set -a; source .env; set +a
registry="${GCP_REGION}-docker.pkg.dev"
image="${registry}/${GCP_PROJECT_ID}/datathlon/morning-job:${tag}"

gcloud auth application-default print-access-token | docker login -u oauth2accesstoken --password-stdin "https://${registry}"
docker build --platform linux/amd64 -f orchestration/Dockerfile -t "$image" .
docker push "$image"
echo "Pushed $image"

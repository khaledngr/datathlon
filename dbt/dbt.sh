#!/usr/bin/env bash
# Run dbt with the repo's .env and this folder's profile, from anywhere:
#   dbt/dbt.sh build          dbt/dbt.sh source freshness          dbt/dbt.sh docs generate
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
set -a; source "$here/../.env"; set +a
cd "$here"
exec "$here/../.venv/bin/dbt" "$@" --profiles-dir "$here"

"""Datathlon · deploy the dbt project INTO Snowflake (dbt Projects on Snowflake, TD 3.2, D-041).

  .venv/bin/python dbt/deploy_to_snowflake.py              # upload the project, new version of OPS.DATATHLON_DBT
  .venv/bin/python dbt/deploy_to_snowflake.py --run build  # same, then run `dbt build --target prod` in Snowflake

TD 3.2 deployed from a Git repository object. Our repository is private (Snowflake would need a GitHub token), so the
files are uploaded to an internal stage instead (PUT), then CREATE DBT PROJECT / ADD VERSION reads them from there.
Each deploy is a new version named after the Git commit: SHOW VERSIONS IN DBT PROJECT tells which code runs.

The seeds live in sources/catalogue/ (one catalogue for the generators and dbt, D-039). Snowflake only sees the
uploaded folder, so the catalogue CSVs are copied into seeds/ of the upload and seed-paths points there.
"""
import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "ingestion"))
from sf_connect import connect  # noqa: E402

PROJECT = "DATATHLON.OPS.DATATHLON_DBT"
STAGE = "DATATHLON.OPS.DBT_SOURCE"
PARTS = ["dbt_project.yml", "profiles.yml", "models", "macros", "tests"]


def bundle(into):
    """The files Snowflake needs, nothing else (no target/, logs/, .user.yml)."""
    src = REPO / "dbt"
    for part in PARTS:
        (shutil.copytree if (src / part).is_dir() else shutil.copy)(src / part, into / part)
    (into / "seeds").mkdir()
    for csv in (REPO / "sources" / "catalogue").glob("*.csv"):
        shutil.copy(csv, into / "seeds" / csv.name)
    project = (into / "dbt_project.yml").read_text()
    project, n = re.subn(r'seed-paths: \["\.\./sources/catalogue"\]', 'seed-paths: ["seeds"]', project)
    if n != 1:
        raise SystemExit("seed-paths not found in dbt_project.yml: update deploy_to_snowflake.py")
    (into / "dbt_project.yml").write_text(project)
    return sorted(p for p in into.rglob("*") if p.is_file())


def version_name():
    sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True, text=True).stdout.strip()
    dirty = subprocess.run(["git", "status", "--porcelain", "dbt", "sources/catalogue"], cwd=REPO,
                           capture_output=True, text=True).stdout.strip()
    return f"{sha}{'-dirty' if dirty else ''}-{datetime.now(timezone.utc):%Y%m%dT%H%M%S}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", metavar="ARGS", help='dbt command to run in Snowflake after the deploy, e.g. "build"')
    a = ap.parse_args()

    version = version_name()
    with tempfile.TemporaryDirectory() as tmp, connect("deploy:dbt", schema="OPS") as sf, sf.cursor() as cur:
        root = Path(tmp)
        files = bundle(root)
        cur.execute(f"CREATE STAGE IF NOT EXISTS {STAGE} COMMENT = 'Uploaded dbt project files, one folder per version'")
        for f in files:
            folder = f.parent.relative_to(root).as_posix()
            target = f"@{STAGE}/{version}" + ("" if folder == "." else f"/{folder}")
            cur.execute(f"PUT 'file://{f.as_posix()}' '{target}' AUTO_COMPRESS = FALSE OVERWRITE = TRUE")
        print(f"Uploaded {len(files)} files to @{STAGE}/{version}")

        cur.execute(f"SHOW DBT PROJECTS LIKE 'DATATHLON_DBT' IN SCHEMA DATATHLON.OPS")
        if cur.fetchall():
            cur.execute(f"ALTER DBT PROJECT {PROJECT} ADD VERSION FROM '@{STAGE}/{version}'")
        else:
            cur.execute(f"CREATE DBT PROJECT {PROJECT} FROM '@{STAGE}/{version}' DEFAULT_TARGET = 'prod' "
                        f"COMMENT = 'Datathlon dbt project, deployed by dbt/deploy_to_snowflake.py (D-041)'")
        cur.execute(f"SHOW VERSIONS IN DBT PROJECT {PROJECT}")
        cols = [d[0] for d in cur.description]
        last = cur.fetchall()[-1]
        print(f"{PROJECT}: version {last[cols.index('name')]} = {version}")

        if a.run:
            cur.execute(f"EXECUTE DBT PROJECT {PROJECT} ARGS = '{a.run} --target prod'")
            success, exception, stdout = cur.fetchone()[:3]
            print(stdout)
            if str(success).lower() != "true":
                raise SystemExit(f"dbt {a.run} FAILED in Snowflake: {exception}")


if __name__ == "__main__":
    main()

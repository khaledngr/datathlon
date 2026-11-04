"""Datathlon · publish the dashboard INSIDE Snowflake (Streamlit in Snowflake, step 11, D-044).

  .venv/bin/python dashboard/deploy_to_snowflake.py

Same pattern as dbt/deploy_to_snowflake.py: the files go to a stage, one folder per version named after the Git commit,
then CREATE OR REPLACE STREAMLIT points the app at that folder. Signs in like the dashboard (snowflake_session.py):
role DATATHLON_ANALYST, secondary roles off. The app is OWNED by the analyst role and runs with its owner's rights, so
inside Snowflake it reads GOLD and nothing else, on the BI warehouse. Every member has the analyst role: they open it
in Snowsight > Projects > Streamlit.
"""
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from snowflake_session import WAREHOUSE, connect  # noqa: E402

APP = "DATATHLON.APPS.DATATHLON_DASHBOARD"
STAGE = "DATATHLON.APPS.DASHBOARD_SOURCE"
FILES = ["streamlit_app.py", "environment.yml", "assets/datathlon-logo.png", "assets/datathlon-mark.png"]
SNOWSIGHT = "https://app.snowflake.com/nvtlkdo/rp44213/#/streamlit-apps/" + APP


def version_name():
    sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=HERE, capture_output=True, text=True).stdout.strip()
    dirty = subprocess.run(["git", "status", "--porcelain", "."], cwd=HERE, capture_output=True, text=True).stdout.strip()
    return f"{sha}{'-dirty' if dirty else ''}-{datetime.now(timezone.utc):%Y%m%dT%H%M%S}"


def main():
    version = version_name()
    with connect() as sf, sf.cursor() as cur:
        cur.execute(f"CREATE STAGE IF NOT EXISTS {STAGE} COMMENT = 'Dashboard files, one folder per version (D-044)'")
        for rel in FILES:
            folder = f"@{STAGE}/{version}" + (f"/{Path(rel).parent.as_posix()}" if "/" in rel else "")
            cur.execute(f"PUT 'file://{(HERE / rel).as_posix()}' '{folder}' AUTO_COMPRESS = FALSE OVERWRITE = TRUE")
        print(f"Uploaded {len(FILES)} files to @{STAGE}/{version}")
        cur.execute(f"""CREATE OR REPLACE STREAMLIT {APP}
                        FROM '@{STAGE}/{version}'
                        MAIN_FILE = 'streamlit_app.py'
                        QUERY_WAREHOUSE = {WAREHOUSE}
                        TITLE = 'Datathlon · sales and stock'
                        COMMENT = 'GOLD dashboard, version {version}, deployed by dashboard/deploy_to_snowflake.py (D-044)'""")
        cur.execute(f"SHOW STREAMLITS LIKE 'DATATHLON_DASHBOARD' IN SCHEMA DATATHLON.APPS")
        cols = [d[0] for d in cur.description]
        row = dict(zip(cols, cur.fetchone()))
        print(f"{APP}: owner {row['owner']}, warehouse {row['query_warehouse']}")
        print(f"Open it: {SNOWSIGHT}")


if __name__ == "__main__":
    main()

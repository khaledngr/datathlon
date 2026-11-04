"""Run every statement of a .sql file in Snowflake as DATATHLON_PIPELINE and print each result (adapted from TD 3
run_sql_file.py).

  .venv/bin/python snowflake/run_sql.py snowflake/stages/02_tills.sql
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ingestion"))
from sf_connect import connect  # noqa: E402

sql_file = Path(sys.argv[1])
# the team that pays for the run in the showback (docs/GOVERNANCE.md): loads are ingestion, the task graph transformation
TEAM = {"stages": "ingestion", "tasks": "transformation"}.get(sql_file.resolve().parent.name, "platform")
with connect(f"{TEAM}:sql:{sql_file.stem}") as conn:
    for cur in conn.execute_string(sql_file.read_text(), remove_comments=True):
        if not cur.description:
            continue
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
        if cols == ["status"]:
            continue
        print("\n" + " | ".join(cols))
        for r in rows[:30]:
            print("   ", " | ".join(str(v)[:60] for v in r))

"""Datathlon · least-privilege check for the dashboard role (step 11, D-027, C7).

  .venv/bin/python dashboard/check_access.py

Signs in like the dashboard (your user from .env, role DATATHLON_ANALYST, warehouse DATATHLON_BI_WH) and switches off
secondary roles, so only the analyst role counts. Expected: every GOLD table readable, BRONZE / SILVER / QUARANTINE /
OPS refused, no write anywhere. Exit 1 if one result is not the expected one.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from snowflake_session import connect  # noqa: E402  same sign-in as the dashboard

CHECKS = [  # (what, SQL, should it work?)
    ("read GOLD.GOLD_SALES_DAILY", "SELECT COUNT(*) FROM DATATHLON.GOLD.GOLD_SALES_DAILY", True),
    ("read GOLD.GOLD_STOCK_COVER_DAILY", "SELECT COUNT(*) FROM DATATHLON.GOLD.GOLD_STOCK_COVER_DAILY", True),
    ("read GOLD.GOLD_DATA_QUALITY_DAILY", "SELECT COUNT(*) FROM DATATHLON.GOLD.GOLD_DATA_QUALITY_DAILY", True),
    ("read GOLD.GOLD_HOLIDAYS", "SELECT COUNT(*) FROM DATATHLON.GOLD.GOLD_HOLIDAYS", True),
    ("read BRONZE.WEB_ORDERS", "SELECT COUNT(*) FROM DATATHLON.BRONZE.WEB_ORDERS", False),
    ("read SILVER.SILVER_WEB_ORDERS", "SELECT COUNT(*) FROM DATATHLON.SILVER.SILVER_WEB_ORDERS", False),
    ("read QUARANTINE.QUARANTINE_TILL_SALES", "SELECT COUNT(*) FROM DATATHLON.QUARANTINE.QUARANTINE_TILL_SALES", False),
    ("read OPS.PIPELINE_RUNS", "SELECT COUNT(*) FROM DATATHLON.OPS.PIPELINE_RUNS", False),
    ("delete from GOLD.GOLD_SALES_DAILY", "DELETE FROM DATATHLON.GOLD.GOLD_SALES_DAILY WHERE 1 = 0", False),
    ("create a table in GOLD", "CREATE TABLE DATATHLON.GOLD.ANALYST_WAS_HERE (x INT)", False),
]


def main():
    ok = True
    with connect() as sf, sf.cursor() as cur:
        cur.execute("SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_SECONDARY_ROLES(), CURRENT_WAREHOUSE()")
        print("Signed in as %s, role %s, secondary roles %s, warehouse %s" % cur.fetchone())
        for what, sql, should_work in CHECKS:
            try:
                cur.execute(sql)
                worked, detail = True, f"{cur.fetchone()[0]} rows" if sql.startswith("SELECT") else "done"
            except Exception as e:  # Snowflake refuses: not authorised or does not exist for this role
                worked, detail = False, str(e).splitlines()[-1][:90]
            good = worked == should_work
            ok &= good
            print(f"{'OK  ' if good else 'FAIL'} {what:42} {'allowed' if worked else 'refused':8} {detail}")
    print("Least privilege as expected." if ok else "UNEXPECTED ACCESS: fix the grants (terraform/roles.tf).")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

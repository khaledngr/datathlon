"""Datathlon · the dashboard's Snowflake sign-in (step 11): read-only role, BI warehouse, secondary roles off.

Settings from the repo's .env: SNOWFLAKE_ACCOUNT, and DASHBOARD_USER / DASHBOARD_PRIVATE_KEY_PATH if set, else your
own SNOWFLAKE_USER / SNOWFLAKE_PRIVATE_KEY_PATH. The user must have the role DATATHLON_ANALYST (Terraform gives it to
the 3 members). Secondary roles are switched off: our users have DEFAULT_SECONDARY_ROLES = ALL, which would add the
engineer's rights and hide a missing grant.
"""
import os
from pathlib import Path

import snowflake.connector
from cryptography.hazmat.primitives import serialization
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

ROLE = "DATATHLON_ANALYST"
WAREHOUSE = "DATATHLON_BI_WH"


def connect():
    key_path = os.environ.get("DASHBOARD_PRIVATE_KEY_PATH") or os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]
    key = serialization.load_pem_private_key(Path(key_path).read_bytes(), password=None)
    con = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ.get("DASHBOARD_USER") or os.environ["SNOWFLAKE_USER"],
        private_key=key.private_bytes(serialization.Encoding.DER, serialization.PrivateFormat.PKCS8,
                                      serialization.NoEncryption()),
        role=ROLE,
        warehouse=WAREHOUSE,
        database="DATATHLON",
        schema="GOLD",
        session_parameters={"QUERY_TAG": "datathlon:dashboard"},  # dashboard cost in QUERY_HISTORY
    )
    con.cursor().execute("USE SECONDARY ROLES NONE")
    return con

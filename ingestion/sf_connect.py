"""Datathlon · one Snowflake connection for every job: the service user DATATHLON_PIPELINE with its key pair (D-034).
Settings from the repo's .env: SNOWFLAKE_ACCOUNT, PIPELINE_USER, PIPELINE_PRIVATE_KEY_PATH, SNOWFLAKE_WAREHOUSE,
SNOWFLAKE_DATABASE.
"""
import os
from pathlib import Path

import snowflake.connector
from cryptography.hazmat.primitives import serialization
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[1] / ".env")


def connect(query_tag, schema="BRONZE"):
    key = serialization.load_pem_private_key(Path(os.environ["PIPELINE_PRIVATE_KEY_PATH"]).read_bytes(), password=None)
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["PIPELINE_USER"],
        private_key=key.private_bytes(serialization.Encoding.DER, serialization.PrivateFormat.PKCS8,
                                      serialization.NoEncryption()),
        role="DATATHLON_ENGINEER",
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "DATATHLON_WH"),
        database=os.environ.get("SNOWFLAKE_DATABASE", "DATATHLON"),
        schema=schema,
        session_parameters={"QUERY_TAG": f"datathlon:{query_tag}"},  # "<team>:<job>": who pays, in the showback
    )

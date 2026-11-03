"""Datathlon · create a key pair for Snowflake key-pair authentication (adapted from TD 2 gen_key.py).

Run once per Snowflake user:  python snowflake/setup/gen_key.py KHALED
Writes the PRIVATE key to ~/.snowflake/datathlon/<user>_rsa_key.p8, OUTSIDE the repo (never share or commit it),
and prints the SQL that registers the public key on the Snowflake user. The public key is not a secret.
"""
import sys
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

if len(sys.argv) != 2:
    raise SystemExit("Usage: python gen_key.py SNOWFLAKE_USER")
user = sys.argv[1].upper()

key_dir = Path.home() / ".snowflake" / "datathlon"
key_dir.mkdir(parents=True, exist_ok=True)
key_dir.chmod(0o700)
key_path = key_dir / f"{user.lower()}_rsa_key.p8"
if key_path.exists():
    raise SystemExit(f"{key_path} already exists - delete it first if you really want a new key.")

private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
key_path.write_bytes(
    private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
)
key_path.chmod(0o600)

public_pem = private_key.public_key().public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
).decode()
public_body = "".join(line for line in public_pem.splitlines() if "-----" not in line)

print(f"Private key written to {key_path}")
print(f"Put this path in .env: SNOWFLAKE_PRIVATE_KEY_PATH={key_path}")
print("\nRun this in Snowsight, signed in as that user (or as an admin):\n")
print(f"ALTER USER {user} SET RSA_PUBLIC_KEY = '{public_body}';")

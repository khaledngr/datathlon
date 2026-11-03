# Setup for each team member

What you need on your laptop and in each account, and why. Done once.

## 1. Tools

| Tool | Why | Install (macOS) | Check |
| --- | --- | --- | --- |
| git + GitHub CLI | Code and pull requests | `brew install git gh` | `gh auth status` |
| Google Cloud CLI | Terraform and GCS access | `brew install --cask google-cloud-sdk` | `gcloud config list` |
| Terraform | Infrastructure as code | `brew install terraform` | `terraform -version` |
| Docker Desktop | Local Postgres and the ingestion job | docker.com | `docker version` |
| Python 3.11+ | Ingestion jobs, generators, Streamlit | `brew install python` | `python3 --version` |

## 2. Accounts (one login per person, decision D-027)

| Account | How you get it | Your role |
| --- | --- | --- |
| GitHub repo `khaledngr/datathlon` | Accept the invitation | write (Khaled admin) |
| Snowflake `NVTLKDO-RP44213` | Robin or Khaled creates your user and gives you a temporary password privately; you change it at first sign-in and set up MFA | `DATATHLON_ENGINEER` (builds the pipeline); the dashboard reads as `DATATHLON_ANALYST` |
| Google Cloud project `datathlon-513514` | Robin adds your `@albertschool.com` account | Editor (Khaled also Project IAM Admin) |

## 3. Your settings

```bash
cp .env.example .env
```

Fill in your own `SNOWFLAKE_USER` and the path to your private key. The key itself stays outside the repo.

### Key pair for scripts

Scripts connect to Snowflake with a key pair, never a password:

1. Create the key on your laptop: `python snowflake/setup/gen_key.py YOUR_USER` writes it to `~/.snowflake/datathlon/`, outside the repo.
2. An admin attaches your **public** key to your user: `ALTER USER <YOU> SET RSA_PUBLIC_KEY = '<public key>';`
3. Put the path of the private key in `.env` (`SNOWFLAKE_PRIVATE_KEY_PATH`).

## 4. Google Cloud sign-in

```bash
gcloud auth login
gcloud config set project datathlon-513514
gcloud auth application-default login
```

The last command lets Terraform use your login.

## Python environment (step 4)

One environment for all the Datathlon scripts, pinned versions in `requirements.txt`:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

`.venv/` is not committed. The local Postgres runs in Docker on port **5433** (5432 is often taken by another local Postgres); its password is a random value you put in your own `.env` (`PGPASSWORD`).


# Step 0 · Google Cloud team access (decision D-027)

Project: **`datathlon-513514`**, owned by Robin. Region for everything: **`europe-west3`** (Frankfurt, same as Snowflake).

Robin is the only **Owner**. Khaled and Rudy get their own access with their `@albertschool.com` Google accounts; nobody shares a login.

## 1. Robin adds Khaled and Rudy (console, 2 minutes)

[console.cloud.google.com](https://console.cloud.google.com/) → select project `datathlon-513514` → **IAM & Admin → IAM → Grant access**.

| Principal | Roles | Why |
| --- | --- | --- |
| `kelnagar@albertschool.com` | **Editor** + **Project IAM Admin** | Runs the setup and Terraform: creates the bucket, the Terraform service account and its permissions |
| `rcausel@albertschool.com` | **Editor** | Builds and tests the pipeline pieces |

Editor is broad. It is acceptable for a 3-person prototype; in production each person would get only the roles of their part (e.g. Storage Admin for ingestion). We say this in the security slide (C7).

Same thing from a terminal, if Robin has `gcloud`:

```bash
gcloud projects add-iam-policy-binding datathlon-513514 --member="user:kelnagar@albertschool.com" --role="roles/editor"
gcloud projects add-iam-policy-binding datathlon-513514 --member="user:kelnagar@albertschool.com" --role="roles/resourcemanager.projectIamAdmin"
gcloud projects add-iam-policy-binding datathlon-513514 --member="user:rcausel@albertschool.com" --role="roles/editor"
```

## 2. Billing and budget (done 2 Nov, decision D-029)

Billing account `014D04-0E9313-35FE88` (Robin's, free trial: €269.43 and 90 days left on 2 Nov).
Budget **`datathlon-cost-guard`**: Billing → Budgets & caps. Alerts only, €10 a month, all services, credits **not** deducted (so it warns even while credits pay), emails to Robin at 50 %, 90 %, 100 % actual and 100 % forecast.

**Never click "Changer" / upgrade**: while the account stays a free trial, Google cannot charge the card.

## 3. Check (each member)

```bash
gcloud auth login
gcloud config set project datathlon-513514
gcloud projects get-iam-policy datathlon-513514 --format="table(bindings.role, bindings.members)"
```

## Later, in step 3 (Terraform, not now)

- Service account `datathlon-terraform` with only the roles Terraform needs; its key never goes in Git.
- GCS bucket in `europe-west3` for landing files, a second one for Terraform state (created once by hand, listed as a manual step).
- Snowflake storage integration: Snowflake gives us a Google service account; we grant it read access on the landing bucket only.

# Step 3c (D-031): the landing bucket on Google Cloud and the link that lets Snowflake read it.
# One apply does both sides: Snowflake creates the integration and gives us its Google service account,
# Terraform then grants that service account read access on the bucket. No copy-paste between consoles.

# ---------- Landing bucket: where the till files, stock CSVs and API JSON arrive ----------
resource "google_storage_bucket" "landing" {
  name                        = "datathlon-landing-513514"
  location                    = var.gcp_region
  uniform_bucket_level_access = true       # permissions on the bucket only, no per-file ACLs
  public_access_prevention    = "enforced" # can never be made public
  force_destroy               = false      # never delete a bucket with data by accident

  lifecycle_rule {
    condition { age = 90 }
    action { type = "Delete" } # raw files kept 90 days: they are in BRONZE by then (cost + GDPR, write it down)
  }

  labels = { project = "datathlon", managed_by = "terraform" }
}

# ---------- Snowflake storage integration (ACCOUNTADMIN only) ----------
resource "snowflake_storage_integration_gcs" "landing" {
  provider                  = snowflake.admin
  name                      = "DATATHLON_GCS_INT"
  enabled                   = true
  storage_allowed_locations = ["gcs://${google_storage_bucket.landing.name}/"] # this bucket only
  comment                   = "Snowflake reads the landing bucket - managed by Terraform"
}

locals {
  # Google service account that Snowflake created for this integration (DESC STORAGE INTEGRATION)
  snowflake_gcs_service_account = snowflake_storage_integration_gcs.landing.describe_output[0].service_account
}

# Read-only on the landing bucket, nothing else: list files (bucket reader) and read them (object viewer).
# Snowflake's loading guide asks for storage.buckets.get, storage.objects.get and storage.objects.list.
resource "google_storage_bucket_iam_member" "snowflake_reads_landing" {
  for_each = toset(["roles/storage.legacyBucketReader", "roles/storage.objectViewer"])
  bucket   = google_storage_bucket.landing.name
  role     = each.key
  member   = "serviceAccount:${local.snowflake_gcs_service_account}"
}

# Engineers can create stages on top of the integration (step 6)
resource "snowflake_grant_privileges_to_account_role" "engineer_integration" {
  provider          = snowflake.security
  account_role_name = snowflake_account_role.engineer.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "INTEGRATION"
    object_name = snowflake_storage_integration_gcs.landing.name
  }
}

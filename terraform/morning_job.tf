# Step 10 (D-044): the morning job runs on Google Cloud, not on a laptop that may be switched off.
#   Cloud Scheduler 05:30 Paris -> Cloud Run job (the Docker image of orchestration/) -> Postgres on Cloud SQL,
#   BRONZE in Snowflake, files in the landing bucket. Then the Snowflake Tasks take over at 06:00.
# Secrets: the Postgres password is made here (random_password, so it is in the private Terraform state); the
# Snowflake private key is NOT: only its public half is in Git, the private half is added to Secret Manager by hand
# (docs/MANUAL_STEPS.md), so it is never in Git nor in the state.

locals {
  morning_job_apis = [
    "run.googleapis.com", "cloudscheduler.googleapis.com", "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com", "sqladmin.googleapis.com",
  ]
  morning_job_image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.jobs.repository_id}/morning-job:${var.morning_job_image_tag}"
}

resource "google_project_service" "morning_job" {
  for_each           = toset(local.morning_job_apis)
  service            = each.key
  disable_on_destroy = false # switching an API off can break other things in the project
}

# ---------- Where the image lives ----------
resource "google_artifact_registry_repository" "jobs" {
  repository_id = "datathlon"
  location      = var.gcp_region
  format        = "DOCKER"
  description   = "Datathlon job images - managed by Terraform"
  labels        = { project = "datathlon", managed_by = "terraform" }
  depends_on    = [google_project_service.morning_job]
}

# ---------- The web shop database: Postgres on Cloud SQL (was Docker on the laptop, step 4) ----------
resource "google_sql_database_instance" "web_shop" {
  name                = "datathlon-web-shop"
  database_version    = "POSTGRES_16" # same major version as the local Docker image postgres:16.4
  region              = var.gcp_region
  deletion_protection = false # synthetic data, rebuilt by generate_orders.py --init: terraform destroy may remove it

  settings {
    tier              = "db-f1-micro" # smallest shared-core machine: about 0.40 EUR a day
    edition           = "ENTERPRISE"  # shared-core tiers only exist in this edition
    availability_type = "ZONAL"
    disk_type         = "PD_HDD"
    disk_size         = 10
    disk_autoresize   = false

    backup_configuration {
      enabled    = true
      start_time = "01:00" # UTC, before the 05:30 Paris job
    }

    # Public IP but no authorised network: nobody connects by IP. The Cloud Run job goes through the Cloud SQL
    # connector, which checks IAM (roles/cloudsql.client) and encrypts the connection.
    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }

    user_labels = { project = "datathlon", managed_by = "terraform" }
  }
  depends_on = [google_project_service.morning_job]
}

resource "google_sql_database" "web_shop" {
  name     = "datathlon_web"
  instance = google_sql_database_instance.web_shop.name
}

resource "random_password" "web_shop" {
  length  = 32
  special = false
}

resource "google_sql_user" "web_shop" {
  name     = "datathlon"
  instance = google_sql_database_instance.web_shop.name
  password = random_password.web_shop.result
}

# ---------- Secrets, kept in the same region as the data ----------
resource "google_secret_manager_secret" "web_shop_password" {
  secret_id = "datathlon-web-shop-password"
  replication {
    user_managed {
      replicas { location = var.gcp_region }
    }
  }
  labels     = { project = "datathlon", managed_by = "terraform" }
  depends_on = [google_project_service.morning_job]
}

resource "google_secret_manager_secret_version" "web_shop_password" {
  secret      = google_secret_manager_secret.web_shop_password.id
  secret_data = random_password.web_shop.result
}

# The value (DATATHLON_PIPELINE's private key for the cloud, public half keys/datathlon_pipeline_cloud.pub) is added
# by hand: gcloud secrets versions add datathlon-pipeline-snowflake-key --data-file=<key.p8>
resource "google_secret_manager_secret" "snowflake_key" {
  secret_id = "datathlon-pipeline-snowflake-key"
  replication {
    user_managed {
      replicas { location = var.gcp_region }
    }
  }
  labels     = { project = "datathlon", managed_by = "terraform" }
  depends_on = [google_project_service.morning_job]
}

# ---------- Who the job runs as, and what it may touch (least privilege) ----------
resource "google_service_account" "morning_job" {
  account_id   = "datathlon-morning-job"
  display_name = "Datathlon morning job (Cloud Run)"
}

resource "google_project_iam_member" "morning_job_cloudsql" {
  project = var.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.morning_job.email}"
}

# Writes the till, stock and API files into the landing bucket only (list, read, create); bucket reader for --check
resource "google_storage_bucket_iam_member" "morning_job_landing" {
  for_each = toset(["roles/storage.objectUser", "roles/storage.legacyBucketReader"])
  bucket   = google_storage_bucket.landing.name
  role     = each.key
  member   = "serviceAccount:${google_service_account.morning_job.email}"
}

resource "google_secret_manager_secret_iam_member" "morning_job_secrets" {
  for_each = {
    password = google_secret_manager_secret.web_shop_password.id
    key      = google_secret_manager_secret.snowflake_key.id
  }
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.morning_job.email}"
}

# ---------- The job ----------
resource "google_cloud_run_v2_job" "morning" {
  name                = "datathlon-morning-job"
  location            = var.gcp_region
  deletion_protection = false
  labels              = { project = "datathlon", managed_by = "terraform" }

  template {
    task_count = 1
    template {
      service_account = google_service_account.morning_job.email
      timeout         = "1200s" # must end well before the 06:00 Snowflake run
      max_retries     = 1       # every step is re-run safe: one more try after a passing glitch

      containers {
        image = local.morning_job_image
        resources {
          limits = { cpu = "1", memory = "1Gi" }
        }
        env {
          name  = "SNOWFLAKE_ACCOUNT"
          value = "${var.organization_name}-${var.account_name}"
        }
        env {
          name  = "PIPELINE_USER"
          value = snowflake_service_user.pipeline.name # the service user, not a person (D-034)
        }
        env {
          name  = "PIPELINE_PRIVATE_KEY_PATH"
          value = "/secrets/snowflake/key.p8"
        }
        env {
          name  = "SNOWFLAKE_WAREHOUSE"
          value = module.pipeline_warehouse.name
        }
        env {
          name  = "SNOWFLAKE_DATABASE"
          value = snowflake_database.datathlon.name
        }
        env {
          name  = "GCP_PROJECT_ID"
          value = var.gcp_project_id
        }
        env {
          name  = "GCS_LANDING_BUCKET"
          value = google_storage_bucket.landing.name
        }
        env {
          name  = "PGHOST" # a folder = a Unix socket, opened by the Cloud SQL connector (volume below)
          value = "/cloudsql/${google_sql_database_instance.web_shop.connection_name}"
        }
        env {
          name  = "PGDATABASE"
          value = google_sql_database.web_shop.name
        }
        env {
          name  = "PGUSER"
          value = google_sql_user.web_shop.name
        }
        env {
          name = "PGPASSWORD"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.web_shop_password.secret_id
              version = "latest"
            }
          }
        }
        # same order as Google returns them (else every plan shows a fake change)
        volume_mounts {
          name       = "snowflake-key"
          mount_path = "/secrets/snowflake"
        }
        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }

      volumes {
        name = "snowflake-key"
        secret {
          secret = google_secret_manager_secret.snowflake_key.secret_id
          items {
            version = "latest"
            path    = "key.p8"
          }
        }
      }
      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [google_sql_database_instance.web_shop.connection_name]
        }
      }
    }
  }

  depends_on = [
    google_project_iam_member.morning_job_cloudsql,
    google_secret_manager_secret_iam_member.morning_job_secrets,
    google_secret_manager_secret_version.web_shop_password,
  ]
}

# ---------- The alarm clock: Cloud Scheduler starts the job every morning ----------
resource "google_service_account" "scheduler" {
  account_id   = "datathlon-scheduler"
  display_name = "Datathlon scheduler (starts the morning job)"
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_runs_job" {
  name     = google_cloud_run_v2_job.morning.name
  location = var.gcp_region
  role     = "roles/run.invoker" # may start this job, nothing else
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_cloud_scheduler_job" "morning" {
  name        = "datathlon-morning-job"
  region      = var.gcp_region
  description = "Starts the Datathlon morning job; the Snowflake Tasks follow at 06:00 - managed by Terraform"
  schedule    = "30 5 * * *"
  time_zone   = "Europe/Paris"

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.gcp_project_id}/locations/${var.gcp_region}/jobs/${google_cloud_run_v2_job.morning.name}:run"
    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
  depends_on = [google_cloud_run_v2_job_iam_member.scheduler_runs_job]
}

# Roles and grants (D-027): engineers build in DATATHLON, analysts only read GOLD.
# Both roles are granted to SYSADMIN so admins keep control of everything they create.

resource "snowflake_account_role" "engineer" {
  provider = snowflake.security
  name     = "DATATHLON_ENGINEER"
  comment  = "Builds the pipeline in DATATHLON - managed by Terraform"
}

resource "snowflake_account_role" "analyst" {
  provider = snowflake.security
  name     = "DATATHLON_ANALYST"
  comment  = "Reads GOLD only (dashboard) - managed by Terraform"
}

resource "snowflake_grant_account_role" "to_sysadmin" {
  for_each         = { engineer = snowflake_account_role.engineer.name, analyst = snowflake_account_role.analyst.name }
  provider         = snowflake.security
  role_name        = each.value
  parent_role_name = "SYSADMIN"
}

resource "snowflake_grant_account_role" "engineer_to_user" {
  for_each  = toset(var.team_users)
  provider  = snowflake.security
  role_name = snowflake_account_role.engineer.name
  user_name = each.key
}

resource "snowflake_grant_account_role" "analyst_to_user" {
  for_each  = toset(var.team_users)
  provider  = snowflake.security
  role_name = snowflake_account_role.analyst.name
  user_name = each.key
}

# ---------- Engineer: both warehouses, the database, full rights in every layer ----------
resource "snowflake_grant_privileges_to_account_role" "engineer_warehouses" {
  for_each          = toset([module.pipeline_warehouse.name, module.bi_warehouse.name])
  provider          = snowflake.security
  account_role_name = snowflake_account_role.engineer.name
  privileges        = ["USAGE", "OPERATE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = each.value
  }
}

resource "snowflake_grant_privileges_to_account_role" "engineer_database" {
  provider          = snowflake.security
  account_role_name = snowflake_account_role.engineer.name
  privileges        = ["USAGE", "MONITOR"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.datathlon.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "engineer_schemas" {
  for_each          = snowflake_schema.layer
  provider          = snowflake.security
  account_role_name = snowflake_account_role.engineer.name
  all_privileges    = true
  on_schema {
    schema_name = each.value.fully_qualified_name
  }
}

# Step 10 (D-041): the engineer owns the task graph and the dbt project in OPS
resource "snowflake_grant_privileges_to_account_role" "engineer_ops_schema" {
  provider          = snowflake.security
  account_role_name = snowflake_account_role.engineer.name
  all_privileges    = true
  on_schema {
    schema_name = snowflake_schema.ops.fully_qualified_name
  }
}

# A task runs with its owner's role, and that role needs EXECUTE TASK on the account (TD 3.2 trap: SYSADMIN did not
# have it). Account privilege: granted by ACCOUNTADMIN.
resource "snowflake_grant_privileges_to_account_role" "engineer_execute_task" {
  provider          = snowflake.admin
  account_role_name = snowflake_account_role.engineer.name
  privileges        = ["EXECUTE TASK"]
  on_account        = true
}

# ---------- Analyst: BI warehouse, GOLD only (the "denied on BRONZE" demo, C7) ----------
resource "snowflake_grant_privileges_to_account_role" "analyst_warehouse" {
  provider          = snowflake.security
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = module.bi_warehouse.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_database" {
  provider          = snowflake.security
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.datathlon.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_gold_schema" {
  provider          = snowflake.security
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = snowflake_schema.layer["GOLD"].fully_qualified_name
  }
}

# The analyst owns the dashboard app (D-044): a Streamlit in Snowflake app runs with its OWNER's rights, so owned by
# the analyst it can read GOLD and nothing else. Rights in APPS only: create the app and the stage of its files.
resource "snowflake_grant_privileges_to_account_role" "analyst_apps_schema" {
  provider          = snowflake.security
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE", "CREATE STREAMLIT", "CREATE STAGE"]
  on_schema {
    schema_name = snowflake_schema.apps.fully_qualified_name
  }
}

# Tables and views that dbt will create later in GOLD are readable automatically
resource "snowflake_grant_privileges_to_account_role" "analyst_gold_future" {
  for_each          = toset(["TABLES", "VIEWS"])
  provider          = snowflake.security
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = each.key
      in_schema          = snowflake_schema.layer["GOLD"].fully_qualified_name
    }
  }
}

# ---------- Service user for the pipeline (step 5, D-031 / D-034) ----------
# The scripts and Tasks run as this user, not as a person. Key pair only (no password, cannot use Snowsight),
# and NO secondary roles: it only ever has DATATHLON_ENGINEER, whatever else exists in the account.
resource "snowflake_service_user" "pipeline" {
  provider                       = snowflake.security
  name                           = "DATATHLON_PIPELINE"
  comment                        = "Datathlon pipeline (ingestion, dbt, Tasks) - managed by Terraform"
  rsa_public_key                 = trimspace(file("${path.module}/keys/datathlon_pipeline.pub"))       # public half: safe in Git
  rsa_public_key_2               = trimspace(file("${path.module}/keys/datathlon_pipeline_cloud.pub")) # second key: the Cloud Run morning job (D-042)
  default_role                   = snowflake_account_role.engineer.name
  default_warehouse              = module.pipeline_warehouse.name
  default_secondary_roles_option = "NONE"
  statement_timeout_in_seconds   = 900 # a stuck query is cancelled after 15 min instead of burning credits
}

resource "snowflake_grant_account_role" "engineer_to_pipeline" {
  provider  = snowflake.security
  role_name = snowflake_account_role.engineer.name
  user_name = snowflake_service_user.pipeline.name
}

# ---------- Failure e-mail (step 10, D-041) ----------
# The task graph's finalizer sends an e-mail when a run fails (SYSTEM$SEND_EMAIL). Snowflake only sends to verified
# e-mail addresses of users of this account; the recipients are kept in DATATHLON.OPS.ALERT_RECIPIENTS, not in Git.
resource "snowflake_email_notification_integration" "alerts" {
  provider = snowflake.admin
  name     = "DATATHLON_ALERTS_EMAIL"
  enabled  = true
  comment  = "Daily pipeline failure e-mails - managed by Terraform"
}

resource "snowflake_grant_privileges_to_account_role" "engineer_alerts_email" {
  provider          = snowflake.admin
  account_role_name = snowflake_account_role.engineer.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "INTEGRATION"
    object_name = snowflake_email_notification_integration.alerts.name
  }
}

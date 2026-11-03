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

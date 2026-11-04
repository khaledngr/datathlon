# Datathlon platform on Snowflake, declared as code (step 3b, D-031).
# terraform plan = preview the changes      terraform apply = make them

locals {
  layers = ["BRONZE", "SILVER", "QUARANTINE", "GOLD"]
}

# ---------- Database and medallion layers ----------
resource "snowflake_database" "datathlon" {
  name    = "DATATHLON"
  comment = "Datathlon pipeline - managed by Terraform, do not change by hand"
}

resource "snowflake_schema" "layer" {
  for_each = toset(local.layers)
  database = snowflake_database.datathlon.name
  name     = each.key
  comment  = "${each.key} layer - managed by Terraform"
}

# ---------- Pipeline objects (step 10, D-041): tasks, procedures, the dbt project, the run log ----------
# Not a data layer: the analyst gets nothing here.
resource "snowflake_schema" "ops" {
  database = snowflake_database.datathlon.name
  name     = "OPS"
  comment  = "Pipeline objects: Snowflake Tasks, load procedures, dbt project, run log - managed by Terraform"
}

# ---------- Dashboard app (step 11, D-044): the Streamlit in Snowflake app and its files ----------
# Not a data layer: no table here. The analyst publishes the app here; GOLD stays read-only for it.
resource "snowflake_schema" "apps" {
  database = snowflake_database.datathlon.name
  name     = "APPS"
  comment  = "Streamlit in Snowflake dashboard and its source stage - managed by Terraform"
}

# ---------- Warehouses (same module, two jobs: credits split by use) ----------
module "pipeline_warehouse" {
  source  = "./modules/warehouse"
  name    = "DATATHLON_WH"
  size    = "XSMALL"
  comment = "Ingestion, dbt and Snowflake Tasks"
}

module "bi_warehouse" {
  source  = "./modules/warehouse"
  name    = "DATATHLON_BI_WH"
  size    = "XSMALL"
  comment = "Streamlit dashboard"
}

# ---------- Cost guard (step 2), now declared as code ----------
# Created by hand in step 2 (snowflake/setup/01_resource_monitor.sql), taken over by Terraform here.
import {
  provider = snowflake.admin
  to       = snowflake_resource_monitor.account
  id       = "DATATHLON_ACCOUNT_MONITOR"
}

resource "snowflake_resource_monitor" "account" {
  provider                  = snowflake.admin
  name                      = "DATATHLON_ACCOUNT_MONITOR"
  credit_quota              = 20
  frequency                 = "MONTHLY"
  start_timestamp           = "2026-11-02T07:51:33.784-08:00" # when it was created in step 2 (the provider needs both)
  notify_users              = ["ROBINCCR", "KHALED"]
  notify_triggers           = [50, 80]
  suspend_trigger           = 100
  suspend_immediate_trigger = 110
}

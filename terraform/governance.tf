# Governance (docs/GOVERNANCE.md): tags on every object, personal data masked by tag, showback / chargeback per team.
# Tags and masking are created as ACCOUNTADMIN: only it may attach a masking policy to a tag.

resource "snowflake_schema" "governance" {
  database = snowflake_database.datathlon.name
  name     = "GOVERNANCE"
  comment  = "Tags, masking policies and budgets - managed by Terraform"
}

# ---------- Tags ----------
# Allowed values are fixed: a typo cannot create a new team or layer. Tags set on a schema are inherited by its tables.
locals {
  tags = {
    COST_CENTER     = { values = ["ingestion", "transformation", "bi", "platform"], comment = "Team that pays for the object: showback / chargeback" }
    OWNER           = { values = ["khaled", "robin", "rudy"], comment = "Team member who answers for the object (docs/OWNERSHIP.md)" }
    DATA_LAYER      = { values = ["bronze", "silver", "quarantine", "gold", "ops", "apps", "governance"], comment = "Medallion layer" }
    DATA_DOMAIN     = { values = ["sales", "web_orders", "stock", "context", "quality", "catalogue", "platform", "cost"], comment = "Business domain of the data" }
    SOURCE_SYSTEM   = { values = ["web_shop_postgres", "store_tills", "store_stock_export", "open_meteo_api", "openholidays_api", "catalogue_seed", "snowflake_metering"], comment = "System the data comes from (lineage)" }
    CONFIDENTIALITY = { values = ["public", "internal", "confidential"], comment = "Who may see it: public data, staff, or need-to-know" }
    ENVIRONMENT     = { values = ["prod", "dev"], comment = "Deployment environment" }
  }

  # Who owns and pays for each schema; the tables inside inherit these tags.
  schema_tags = {
    BRONZE     = { DATA_LAYER = "bronze", OWNER = "khaled", COST_CENTER = "ingestion" }
    SILVER     = { DATA_LAYER = "silver", OWNER = "robin", COST_CENTER = "transformation" }
    QUARANTINE = { DATA_LAYER = "quarantine", OWNER = "robin", COST_CENTER = "transformation" }
    GOLD       = { DATA_LAYER = "gold", OWNER = "robin", COST_CENTER = "transformation" }
    OPS        = { DATA_LAYER = "ops", OWNER = "robin", COST_CENTER = "transformation" }
    APPS       = { DATA_LAYER = "apps", OWNER = "rudy", COST_CENTER = "bi" }
    GOVERNANCE = { DATA_LAYER = "governance", OWNER = "khaled", COST_CENTER = "platform" }
  }

  # Bronze tables are created by the load scripts, once: their source, domain and confidentiality.
  bronze_tags = {
    WEB_ORDERS      = { SOURCE_SYSTEM = "web_shop_postgres", DATA_DOMAIN = "web_orders", CONFIDENTIALITY = "confidential" }
    WEB_ORDER_LINES = { SOURCE_SYSTEM = "web_shop_postgres", DATA_DOMAIN = "web_orders", CONFIDENTIALITY = "internal" }
    TILL_SALES_RAW  = { SOURCE_SYSTEM = "store_tills", DATA_DOMAIN = "sales", CONFIDENTIALITY = "confidential" }
    STOCK_SNAPSHOTS = { SOURCE_SYSTEM = "store_stock_export", DATA_DOMAIN = "stock", CONFIDENTIALITY = "internal" }
    STOCK_CONTROL   = { SOURCE_SYSTEM = "store_stock_export", DATA_DOMAIN = "stock", CONFIDENTIALITY = "internal" }
    WEATHER_RAW     = { SOURCE_SYSTEM = "open_meteo_api", DATA_DOMAIN = "context", CONFIDENTIALITY = "public" }
    HOLIDAYS_RAW    = { SOURCE_SYSTEM = "openholidays_api", DATA_DOMAIN = "context", CONFIDENTIALITY = "public" }
    LOAD_RUNS       = { DATA_DOMAIN = "platform", CONFIDENTIALITY = "internal" }
  }

  # Warehouses and the service user: who pays for the compute
  warehouse_tags = {
    (module.pipeline_warehouse.name) = { COST_CENTER = "platform", OWNER = "khaled" }
    (module.bi_warehouse.name)       = { COST_CENTER = "bi", OWNER = "rudy" }
  }

  # One association per (object type, tag, value): flatten everything above
  associations = merge(
    { "DATABASE/ENVIRONMENT/prod" = { type = "DATABASE", tag = "ENVIRONMENT", value = "prod", objects = [snowflake_database.datathlon.fully_qualified_name] } },
    { for k in distinct(flatten([for s, t in local.schema_tags : [for tag, v in t : "${tag}/${v}"]])) :
      "SCHEMA/${k}" => {
        type    = "SCHEMA", tag = split("/", k)[0], value = split("/", k)[1]
        objects = [for s, t in local.schema_tags : "\"DATATHLON\".\"${s}\"" if lookup(t, split("/", k)[0], "") == split("/", k)[1]]
      }
    },
    { for k in distinct(flatten([for s, t in local.bronze_tags : [for tag, v in t : "${tag}/${v}"]])) :
      "TABLE/${k}" => {
        type    = "TABLE", tag = split("/", k)[0], value = split("/", k)[1]
        objects = [for s, t in local.bronze_tags : "\"DATATHLON\".\"BRONZE\".\"${s}\"" if lookup(t, split("/", k)[0], "") == split("/", k)[1]]
      }
    },
    { for k in distinct(flatten([for s, t in local.warehouse_tags : [for tag, v in t : "${tag}/${v}"]])) :
      "WAREHOUSE/${k}" => {
        type    = "WAREHOUSE", tag = split("/", k)[0], value = split("/", k)[1]
        objects = [for s, t in local.warehouse_tags : "\"${s}\"" if lookup(t, split("/", k)[0], "") == split("/", k)[1]]
      }
    },
    { "USER/COST_CENTER/platform" = { type = "USER", tag = "COST_CENTER", value = "platform", objects = ["\"${snowflake_service_user.pipeline.name}\""] } },
  )
}

resource "snowflake_tag" "this" {
  for_each               = local.tags
  provider               = snowflake.admin
  database               = snowflake_database.datathlon.name
  schema                 = snowflake_schema.governance.name
  name                   = each.key
  ordered_allowed_values = each.value.values
  comment                = "${each.value.comment} - managed by Terraform"
}

resource "snowflake_tag_association" "this" {
  for_each           = local.associations
  provider           = snowflake.admin
  object_type        = each.value.type
  object_identifiers = each.value.objects
  tag_id             = snowflake_tag.this[each.value.tag].fully_qualified_name
  tag_value          = each.value.value
}

# ---------- Personal data: tag-based dynamic masking ----------
# Datathlon keeps no name, e-mail or address (GDPR by design), but two identifiers still point to a person:
# the web customer code and the loyalty card number inside the raw till line. Any column tagged PII is masked by the
# policy of its data type. Only the primary role DATATHLON_PII_READER sees clear values (CURRENT_ROLE, not secondary
# roles: an engineer running dbt never reads them in clear, so silver only ever stores pseudonyms).
# Masked value = SHA-256: the same person always gets the same pseudonym, so counts and joins still work.
resource "snowflake_masking_policy" "pii_string" {
  provider = snowflake.admin
  database = snowflake_database.datathlon.name
  schema   = snowflake_schema.governance.name
  name     = "PII_STRING"
  argument {
    name = "VAL"
    type = "VARCHAR"
  }
  return_data_type = "VARCHAR"
  body             = <<-EOT
    CASE
      WHEN CURRENT_ROLE() = 'DATATHLON_PII_READER' THEN VAL
      WHEN VAL IS NULL THEN NULL
      ELSE SHA2(VAL)
    END
  EOT
  comment          = "PII text: clear for DATATHLON_PII_READER, SHA-256 pseudonym for everyone else - managed by Terraform"
}

resource "snowflake_masking_policy" "pii_variant" {
  provider = snowflake.admin
  database = snowflake_database.datathlon.name
  schema   = snowflake_schema.governance.name
  name     = "PII_VARIANT"
  argument {
    name = "VAL"
    type = "VARIANT"
  }
  return_data_type = "VARIANT"
  body             = <<-EOT
    CASE
      WHEN CURRENT_ROLE() = 'DATATHLON_PII_READER' THEN VAL
      WHEN NOT IS_OBJECT(VAL) OR VAL:loyalty_id IS NULL OR IS_NULL_VALUE(VAL:loyalty_id) THEN VAL
      ELSE OBJECT_INSERT(VAL, 'loyalty_id', SHA2(VAL:loyalty_id::STRING), TRUE)
    END
  EOT
  comment          = "Raw till line: loyalty card number replaced by its SHA-256 except for DATATHLON_PII_READER - managed by Terraform"
}

resource "snowflake_tag" "pii" {
  provider               = snowflake.admin
  database               = snowflake_database.datathlon.name
  schema                 = snowflake_schema.governance.name
  name                   = "PII"
  ordered_allowed_values = ["direct_identifier", "pseudonymised"]
  masking_policies       = [snowflake_masking_policy.pii_string.fully_qualified_name, snowflake_masking_policy.pii_variant.fully_qualified_name]
  comment                = "Personal data: a column with this tag is masked automatically - managed by Terraform"
}

# Only admins may say what is personal data: engineers get no APPLY on this tag, so they cannot unmask a column.
resource "snowflake_tag_association" "pii" {
  for_each = {
    WEB_ORDERS     = "CUSTOMER_REF"
    TILL_SALES_RAW = "RAW"
  }
  provider           = snowflake.admin
  object_type        = "COLUMN"
  object_identifiers = ["\"DATATHLON\".\"BRONZE\".\"${each.key}\".\"${each.value}\""]
  tag_id             = snowflake_tag.pii.fully_qualified_name
  tag_value          = "direct_identifier"
}

# ---------- Role that may see personal data in clear (support, data protection officer) ----------
resource "snowflake_account_role" "pii_reader" {
  provider = snowflake.security
  name     = "DATATHLON_PII_READER"
  comment  = "Sees personal identifiers in clear in BRONZE and SILVER (must be the primary role) - managed by Terraform"
}

resource "snowflake_grant_account_role" "pii_reader_to_sysadmin" {
  provider         = snowflake.security
  role_name        = snowflake_account_role.pii_reader.name
  parent_role_name = "SYSADMIN"
}

resource "snowflake_grant_account_role" "pii_reader_to_user" {
  for_each  = toset(var.pii_readers)
  provider  = snowflake.security
  role_name = snowflake_account_role.pii_reader.name
  user_name = each.key
}

resource "snowflake_grant_privileges_to_account_role" "pii_reader_warehouse" {
  provider          = snowflake.security
  account_role_name = snowflake_account_role.pii_reader.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = module.pipeline_warehouse.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "pii_reader_database" {
  provider          = snowflake.security
  account_role_name = snowflake_account_role.pii_reader.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.datathlon.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "pii_reader_schemas" {
  for_each          = toset(["BRONZE", "SILVER"])
  provider          = snowflake.security
  account_role_name = snowflake_account_role.pii_reader.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = snowflake_schema.layer[each.key].fully_qualified_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "pii_reader_tables" {
  for_each          = toset(["BRONZE", "SILVER"])
  provider          = snowflake.security
  account_role_name = snowflake_account_role.pii_reader.name
  privileges        = ["SELECT"]
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = snowflake_schema.layer[each.key].fully_qualified_name
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "pii_reader_future_tables" {
  for_each          = toset(["BRONZE", "SILVER"])
  provider          = snowflake.security
  account_role_name = snowflake_account_role.pii_reader.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = snowflake_schema.layer[each.key].fully_qualified_name
    }
  }
}

# ---------- Engineers: tag the tables dbt builds, read the cost views for showback ----------
resource "snowflake_grant_privileges_to_account_role" "engineer_governance_schema" {
  provider          = snowflake.security
  account_role_name = snowflake_account_role.engineer.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = snowflake_schema.governance.fully_qualified_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "engineer_apply_tags" {
  for_each          = snowflake_tag.this # every tag except PII
  provider          = snowflake.admin
  account_role_name = snowflake_account_role.engineer.name
  privileges        = ["APPLY"]
  on_schema_object {
    object_type = "TAG"
    object_name = each.value.fully_qualified_name
  }
}

# Credits per warehouse and per query (ACCOUNT_USAGE), for the showback model gold_cost_showback_daily
resource "snowflake_grant_database_role" "engineer_usage_views" {
  for_each           = toset(["USAGE_VIEWER", "GOVERNANCE_VIEWER"])
  provider           = snowflake.admin
  database_role_name = "\"SNOWFLAKE\".\"${each.key}\""
  parent_role_name   = snowflake_account_role.engineer.name
}

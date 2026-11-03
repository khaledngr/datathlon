output "database" { value = snowflake_database.datathlon.name }
output "warehouses" { value = [module.pipeline_warehouse.name, module.bi_warehouse.name] }
output "roles" { value = [snowflake_account_role.engineer.name, snowflake_account_role.analyst.name] }
output "landing_bucket" { value = google_storage_bucket.landing.url }
output "snowflake_gcs_service_account" { value = local.snowflake_gcs_service_account }

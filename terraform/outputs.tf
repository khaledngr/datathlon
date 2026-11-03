output "database" { value = snowflake_database.datathlon.name }
output "warehouses" { value = [module.pipeline_warehouse.name, module.bi_warehouse.name] }
output "roles" { value = [snowflake_account_role.engineer.name, snowflake_account_role.analyst.name] }

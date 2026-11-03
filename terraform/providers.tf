# Three connections to the same Snowflake account, one per job (least privilege, D-031):
#   SYSADMIN      creates the database, schemas and warehouses
#   SECURITYADMIN creates roles and grants
#   ACCOUNTADMIN  only for what Snowflake allows nobody else to do (resource monitor, storage integration)
# Sign-in with a key pair (snowflake/setup/gen_key.py): no password, no MFA prompt.
provider "snowflake" {
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.user
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.private_key_path)
  role              = "SYSADMIN"
}

provider "snowflake" {
  alias             = "security"
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.user
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.private_key_path)
  role              = "SECURITYADMIN"
}

provider "snowflake" {
  alias             = "admin"
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.user
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.private_key_path)
  role              = "ACCOUNTADMIN"
}

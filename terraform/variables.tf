variable "organization_name" {
  description = "First part of the account identifier NVTLKDO-RP44213"
  type        = string
  default     = "NVTLKDO"
}

variable "account_name" {
  description = "Second part of the account identifier NVTLKDO-RP44213"
  type        = string
  default     = "RP44213"
}

variable "user" {
  description = "YOUR Snowflake user, the one with a registered key pair (e.g. KHALED)"
  type        = string
}

variable "private_key_path" {
  description = "Path to YOUR private key, outside the repo (~/.snowflake/datathlon/<user>_rsa_key.p8). Never commit the key."
  type        = string
}

variable "team_users" {
  description = "Snowflake users of the 3 members: they get the engineer and analyst roles"
  type        = list(string)
  default     = ["ROBINCCR", "KHALED", "RUDY"]
}

variable "gcp_project_id" {
  description = "Google Cloud project (Robin's, with the free trial credits)"
  type        = string
  default     = "datathlon-513514"
}

variable "gcp_region" {
  description = "Same region as the Snowflake account (GCP_EUROPE_WEST3): no cross-region transfer cost"
  type        = string
  default     = "europe-west3"
}

variable "morning_job_image_tag" {
  description = "Version of the morning job image in Artifact Registry (orchestration/Dockerfile); a new tag = a new deploy"
  type        = string
  default     = "1.1.0"
}

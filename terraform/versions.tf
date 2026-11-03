terraform {
  required_version = ">= 1.9.0"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.22" # pinned major version: same reflex as Docker (TD 4.2)
    }
  }

  # Remote state: bucket created once by hand (D-031), versioned, private. Locking is built in.
  backend "gcs" {
    bucket = "datathlon-tfstate-513514"
    prefix = "platform"
  }
}

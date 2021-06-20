variable "org_id" {
  type        = string
  description = "Organisation ID"
}

variable "billing_account_id" {
  type        = string
  description = "Billing account ID"
}

variable "gcs_region" {
  type        = string
  description = "Region for GCS bucket for Terraform state"
}

variable "parent_folder_name" {
  type = string
}

variable "lz_folder_name" {
  type = string
}

variable "seed_project_id" {
  type        = string
  description = "Project ID for seed project"
}

variable "tf_state_bucket_name" {
  type        = string
  description = "GCS bucket name for Terraform state"
}

variable "enabled_apis" {
  type        = list(string)
  description = "List of APIs to enable in seed project"
}

variable "tf_sa_name" {
  type        = string
  description = "Service account name for LZ foundation provisioning"
}

variable "tf_iam_folder_roles" {
  type        = list(string)
  description = "List of folder level IAM roles to assign to Terraform service account"
}

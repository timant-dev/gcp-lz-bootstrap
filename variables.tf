variable "org_id" {
  type        = string
  description = "Organisation ID"
}

variable "org_domain" {
  type        = string
  description = "Organisation domain name"
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

variable "artefacts_folder_name" {
  type = string
}

variable "root_envs_folder_name" {
  type        = string
  description = "Root environment folder for production, non-production and development workload environments"
}

variable "seed_project_id" {
  type        = string
  description = "Project ID for seed project"
}

variable "artefact_project_id" {
  type        = string
  description = "Project ID for artefact registry project"
}

variable "tf_state_bucket_name" {
  type        = string
  description = "GCS bucket name for Terraform state"
}

variable "cb_artefacts_bucket_name" {
  type        = string
  description = "GCS bucket name for Cloud Build logs and artefacts"
}

variable "tf_sa_name" {
  type        = string
  description = "Service account name for LZ foundation provisioning"
}

variable "enabled_apis" {
  type        = list(string)
  description = "List of APIs to enable in seed project"
}

variable "registry_enabled_apis" {
  type        = list(string)
  description = "List of APIs to enable in registry project"
}

variable "tf_iam_org_roles" {
  type        = list(string)
  description = "List of org level IAM roles to assign to Terraform service account"
}

variable "tf_iam_folder_roles" {
  type        = list(string)
  description = "List of folder level IAM roles to assign to Terraform service account"
}

variable "tf_iam_project_roles" {
  type        = list(string)
  description = "List of project level IAM roles to assign to Terraform service account"
}

variable "artefact_registry_repo_id" {
  type        = string
  description = "Artefact Registry repo name"
}

variable "org_phase_repo_name" {
  type        = string
  description = "Cloud Source Repository name for ORG phase repo"
  default     = "lz-org"
}

variable "policy_lib_repo_name" {
  type        = string
  description = "Cloud Source Repository name for OPA policy library repo"
}

variable "org_repo_policy_lib_trigger_branch" {
  type        = string
  description = "Org phase Cloud Source Repository branch name to trigger Cloud Build job to populate policy-lib repo"
  default     = "main"
}

variable "enable_cb_triggers" {
  type        = bool
  description = "Toggle to enable the provisioning of Cloud Build triggers"
  default     = false
}

variable "policy_lib_cb_job_config" {
  type        = string
  description = "Cloud Build config file name for policy-lib job"
  default     = "cloudbuild-populate-policy-lib.yaml"
}

variable "org_repo_deploy_org_trigger_branch" {
  type        = string
  description = "Org phase Cloud Source Repository branch name to trigger Cloud Build job to deploy org resources"
  default     = "main"
}

variable "plan_org_cb_job_config" {
  type        = string
  description = "Cloud Build config file name for org plan job"
  default     = "cloudbuild-tf-plan-lz-org.yaml"
}

variable "terraform_builder_version" {
  type        = string
  description = "Terraform version to use in Cloud Build Terraform builder image"
  default     = "1.0.1"
}

variable "terraform_builder_shasum" {
  type        = string
  description = "Terraform version SHA sum to use in Cloud Build Terraform builder image"
  default     = "da94657593636c8d35a96e4041136435ff58bb0061245b7d0f82db4a7728cef3"
}

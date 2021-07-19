variable "org_id" {
  type        = string
  description = "Organisation ID"
}

variable "org_domain" {
  type        = string
  description = "Organisation domain name"
}

variable "client_short_name" {
  type        = string
  description = "Short name for client to be used as prefix for git repo branches"
}

variable "billing_account_id" {
  type        = string
  description = "Billing account ID"
}

variable "gcs_region" {
  type        = string
  description = "Region for GCS bucket for Terraform state"
}

variable "default_region" {
  type        = string
  description = "Default region for landing resources"
}

variable "parent_folder_name" {
  type    = string
  default = "bootstrap"
}

variable "artefacts_folder_name" {
  type    = string
  default = "artefacts"
}

variable "root_envs_folder_name" {
  type        = string
  description = "Root environment folder for production, non-production and development workload environments"
  default     = "envs"
}

variable "seed_project_id" {
  type        = string
  description = "Project ID for seed project"
  default     = "seed"
}

variable "artefact_project_id" {
  type        = string
  description = "Project ID for artefact registry project"
  default     = "artefact-registry"
}

variable "tf_state_bucket_name" {
  type        = string
  description = "GCS bucket name for Terraform state"
  default     = "lz-tf-state-seed"
}

variable "cb_artefacts_bucket_name" {
  type        = string
  description = "GCS bucket name for Cloud Build logs and artefacts"
  default     = "lz-cb-artefacts-seed"
}

variable "tf_sa_name" {
  type        = string
  description = "Service account name for LZ foundation provisioning"
  default     = "terraform-core"
}

variable "enabled_apis" {
  type        = list(string)
  description = "List of APIs to enable in seed project"
  default = [
    "cloudapis.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "containerregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "sourcerepo.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com"
  ]
}

variable "registry_enabled_apis" {
  type        = list(string)
  description = "List of APIs to enable in registry project"
  default = [
    "artifactregistry.googleapis.com",
    "sourcerepo.googleapis.com",
  ]
}

variable "tf_iam_org_roles" {
  type        = list(string)
  description = "List of org level IAM roles to assign to Terraform service account"
  default = [
    "roles/billing.user",
    "roles/cloudbuild.builds.editor",
    "roles/resourcemanager.folderAdmin",
    "roles/resourcemanager.organizationAdmin",
    "roles/resourcemanager.projectCreator",
    "roles/resourcemanager.projectDeleter",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/source.admin",
    "roles/storage.admin",
  ]
}

variable "tf_iam_folder_roles" {
  type        = list(string)
  description = "List of folder level IAM roles to assign to Terraform service account"
  default     = []
}

variable "tf_iam_project_roles" {
  type        = list(string)
  description = "List of project level IAM roles to assign to Terraform service account"
  default = [
    "roles/cloudbuild.builds.editor",
    "roles/secretmanager.secretVersionManager",
  ]
}

variable "artefact_registry_repo_id" {
  type        = string
  description = "Artefact Registry repo name"
  default     = "artefact-repo"
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

variable "terraform_validator_version" {
  type        = string
  description = "Terraform Validator binary version number"
  default     = "v0.2.0"
}

variable "org_phase_repo_name" {
  type        = string
  description = "Cloud Source Repository name for ORG phase repo"
  default     = "gcp-lz-org"
}

variable "policy_lib_repo_name" {
  type        = string
  description = "Cloud Source Repository name for OPA policy library repo"
  default     = "policy-lib"
}

variable "enable_cb_triggers" {
  type        = bool
  description = "Toggle to enable the provisioning of Cloud Build triggers"
  default     = false
}

variable "plan_trigger_branch_suffix" {
  type        = string
  description = "Cloud Source Repository branch name suffix to trigger Cloud Build job to deploy org resources"
  default     = "lz-plan"
}

variable "apply_trigger_branch_suffix" {
  type        = string
  description = "Org phase Cloud Source Repository branch name to trigger Cloud Build job to deploy org resources"
  default     = "lz-apply"
}

variable "destroy_trigger_branch_suffix" {
  type        = string
  description = "Cloud Source Repository branch name suffix to trigger Cloud Build job to destroy org resources"
  default     = "lz-destroy"
}

variable "plan_org_cb_job_config" {
  type        = string
  description = "Cloud Build config file name for org plan job"
  default     = "cloudbuild-tf-plan-lz-org.yaml"
}

variable "apply_org_cb_job_config" {
  type        = string
  description = "Cloud Build config file name for org apply job"
  default     = "cloudbuild-tf-apply-lz-org.yaml"
}

variable "destroy_org_cb_job_config" {
  type        = string
  description = "Cloud Build config file name for org destroy job"
  default     = "cloudbuild-tf-destroy-lz-org.yaml"
}

variable "clone_tf_csr_repo_name" {
  type        = string
  description = "Name for cloned Terraform CSR repo in Cloud Build builder workspace"
  default     = "gcp_lz_org_clone"
}

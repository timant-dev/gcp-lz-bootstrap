resource "random_id" "rand_id" {
  byte_length = 4
}

locals {
  tf_state_bucket_name       = "${var.tf_state_bucket_name}-${random_id.rand_id.hex}"
  cb_artefacts_bucket_name   = "${var.cb_artefacts_bucket_name}-${random_id.rand_id.hex}"
  seed_project_unique_id     = "${var.seed_project_id}-${random_id.rand_id.hex}"
  registry_project_unique_id = "${var.artefact_project_id}-${random_id.rand_id.hex}"
}

resource "google_folder" "bootstrap" {
  display_name = var.parent_folder_name
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "artefacts" {
  display_name = var.artefacts_folder_name
  parent       = "organizations/${var.org_id}"
}

resource "google_project" "seed" {
  name                = var.seed_project_id
  project_id          = local.seed_project_unique_id
  auto_create_network = false
  billing_account     = var.billing_account_id
  folder_id           = google_folder.bootstrap.folder_id
  skip_delete         = false
}

resource "google_project_service" "enabled-apis" {
  for_each                   = toset(var.enabled_apis)
  service                    = each.key
  project                    = google_project.seed.project_id
  disable_dependent_services = true
  depends_on = [
    google_folder.bootstrap,
    google_project.seed
  ]
}

resource "google_project" "registry" {
  name                = var.artefact_project_id
  project_id          = local.registry_project_unique_id
  auto_create_network = false
  billing_account     = var.billing_account_id
  folder_id           = google_folder.artefacts.folder_id
  skip_delete         = false
}

resource "google_project_service" "registry-enabled-apis" {
  for_each                   = toset(var.registry_enabled_apis)
  service                    = each.key
  project                    = google_project.registry.project_id
  disable_dependent_services = true
  depends_on = [
    google_folder.artefacts,
    google_project.registry
  ]
}

resource "google_storage_bucket" "tf-seed-state-bucket" {
  project                     = google_project.seed.project_id
  name                        = local.tf_state_bucket_name
  location                    = var.gcs_region
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  depends_on = [
    google_project_service.enabled-apis
  ]
}

resource "google_storage_bucket" "cloud-build-logs-artefacts" {
  project                     = google_project.seed.project_id
  name                        = local.tf_state_bucket_name
  location                    = var.gcs_region
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  depends_on = [
    google_project_service.enabled-apis
  ]
}

resource "google_service_account" "tf-sa" {
  account_id   = var.tf_sa_name
  display_name = var.tf_sa_name
  project      = google_project.seed.project_id
  depends_on = [
    google_storage_bucket.tf-seed-state-bucket
  ]
}

resource "google_organization_iam_binding" "tf-sa-org-iam-roles" {
  for_each = length(var.tf_iam_org_roles) == 0 ? [] : toset(var.tf_iam_org_roles)
  org_id   = var.org_id
  members = [
    "serviceAccount:${google_service_account.tf-sa.email}"
  ]
  role = each.value
  depends_on = [
    google_service_account.tf-sa
  ]
}

resource "google_folder_iam_binding" "tf-sa-folder-iam-roles" {
  for_each = length(var.tf_iam_folder_roles) == 0 ? [] : toset(var.tf_iam_folder_roles)
  folder   = google_folder.lz.folder_id
  members = [
    "serviceAccount:${google_service_account.tf-sa.email}"
  ]
  role = each.value
  depends_on = [
    google_service_account.tf-sa
  ]
}

resource "google_storage_bucket_iam_binding" "tf-sa-gcs-admin" {
  bucket = google_storage_bucket.tf-seed-state-bucket.id
  members = [
    "serviceAccount:${google_service_account.tf-sa.email}"
  ]
  role = "roles/storage.admin"
  depends_on = [
    google_service_account.tf-sa
  ]
}

resource "google_service_account_iam_binding" "cb-impersonate-tf-sa" {
  service_account_id = google_service_account.tf-sa.id
  members            = ["serviceAccount:${google_project.seed.number}@cloudbuild.gserviceaccount.com"]
  role               = "roles/iam.serviceAccountTokenCreator"
  depends_on = [
    google_folder_iam_member.tf-sa-folder-iam-roles
  ]
}

resource "google_storage_bucket_iam_binding" "cb-sa-gcs-admin" {
  bucket = google_storage_bucket.tf-seed-state-bucket.id
  members = [
    "serviceAccount:${google_project.seed.number}@cloudbuild.gserviceaccount.com"
  ]
  role = "roles/storage.admin"
  depends_on = [
    google_storage_bucket.tf-seed-state-bucket
  ]
}

# Create an Artifact Registry repo for builder images and cloud build artefacts

resource "google_artifact_registry_repository" "cb-registry" {
  provider      = google-beta
  repository_id = var.artefact_registry_repo_id
  location      = var.gcs_region
  project       = google_project.registry.project_id
  format        = "DOCKER"
  depends_on = [
    google_project_service.registry-enabled-apis
  ]
}

# Grant read/write access to artefact registry to Terraform service account

resource "google_project_iam_binding" "cb-registry-read-write" {
  project = google_project.registry.project_id
  members = ["serviceAccount:${google_service_account.tf-sa.email}"]
  role    = "roles/artifactregistry.writer"
  depends_on = [
    google_artifact_registry_repository.cb-registry
  ]
}

# Create a cloud source repo for the OPA policy library to be used by Terraform Validator

resource "google_sourcerepo_repository" "policy-lib-repo" {
  name    = var.policy_lib_repo_name
  project = google_project.registry.project_id
  depends_on = [
    google_project_service.registry-enabled-apis
  ]
}

# Grant read/write access to the policy lib repo to Terraform service account

resource "google_sourcerepo_repository_iam_binding" "policy-lib-repo-read-write" {
  project = google_project.registry.project_id
  members = ["serviceAccount:${google_service_account.tf-sa.email}"]
  role    = "roles/source.writer"
  depends_on = [
    google_sourcerepo_repository.policy-lib-repo
  ]
}

# Create a cloud source repo for the ORG phase Terraform code
# NB: This will require a subsequent manual step to enable mirroring
# to a private GitHub repo

resource "google_sourcerepo_repository" "org-phase-repo" {
  name    = var.org_phase_repo_name
  project = google_project.seed.project_id
  depends_on = [
    google_project_service.enabled-apis
  ]
}

# Create Cloud Build trigger to populate policy-lib repo
# NB: Terraform Google provider does not support config of manual
# Cloud Build triggers currently. However once created, this trigger
# can be executed manually in the GCP Console

resource "google_cloudbuild_trigger" "populate-policy-lib" {
  trigger_template {
    repo_name   = google_sourcerepo_repository.org-phase-repo.name
    branch_name = var.org_repo_policy_lib_trigger_branch
  }
  substitutions = {
    _TF_SA              = "${google_service_account.tf-sa.email}"
    _POLICY_LIB_PROJECT = "${google_project.registry.project_name}"
    _POLICY_LIB_REPO    = "${google_sourcerepo_repository.org-phase-repo.id}"
  }
  filename = var.policy_lib_cb_job_config
  depends_on = [
    google_sourcerepo_repository.org_phase_repo
  ]
}

# Create Cloud Build trigger to run the core landing zone ORG deployment phase

resource "google_cloudbuild_trigger" "plan-org-phase" {
  trigger_template {
    repo_name   = google_sourcerepo_repository.org-phase-repo.name
    branch_name = var.org_repo_deploy_org_trigger_branch
  }
  substitutions = {
    _TF_SA              = "${google_service_account.tf-sa.email}"
    _TF_BUCKET          = "${google_storage_bucket.tf-seed-state-bucket.id}"
    _CB_ARTEFACT_BUCKET = "${google_storage_bucket.cloud-build-logs-artefacts.id}"
  }
  filename = var.plan_org_cb_job_config
  depends_on = [
    google_sourcerepo_repository.policy-lib-repo
  ]
}


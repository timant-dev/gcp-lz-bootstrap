resource "random_id" "rand_id" {
  byte_length = 4
}

locals {
  tf_state_bucket_name       = "${var.tf_state_bucket_name}-${random_id.rand_id.hex}"
  cb_artefacts_bucket_name   = "${var.cb_artefacts_bucket_name}-${random_id.rand_id.hex}"
  seed_project_unique_id     = "${var.seed_project_id}-${random_id.rand_id.hex}"
  registry_project_unique_id = "${var.artefact_project_id}-${random_id.rand_id.hex}"
  plan_branch_name           = "${var.client_short_name}-${var.plan_trigger_branch_suffix}"
  apply_branch_name          = "${var.client_short_name}-${var.apply_trigger_branch_suffix}"
  destroy_branch_name        = "${var.client_short_name}-${var.destroy_trigger_branch_suffix}"
}

# Create org-level root folders org/bootstrap and org/artefacts

resource "google_folder" "bootstrap" {
  display_name = var.parent_folder_name
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "artefacts" {
  display_name = var.artefacts_folder_name
  parent       = "organizations/${var.org_id}"
}

# Create seed project

resource "google_project" "seed" {
  name                = var.seed_project_id
  project_id          = local.seed_project_unique_id
  auto_create_network = false
  billing_account     = var.billing_account_id
  folder_id           = google_folder.bootstrap.folder_id
  skip_delete         = false
}

# Enable APIs on seed project

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

# Create registry project

resource "google_project" "registry" {
  name                = var.artefact_project_id
  project_id          = local.registry_project_unique_id
  auto_create_network = false
  billing_account     = var.billing_account_id
  folder_id           = google_folder.artefacts.folder_id
  skip_delete         = false
}

# Enable required APIs on registry project

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

# Create GCS bucket for Terraform state remote backend

resource "google_storage_bucket" "tf-seed-state-bucket" {
  project                     = google_project.seed.project_id
  name                        = local.tf_state_bucket_name
  location                    = var.gcs_region
  force_destroy               = var.state_force_destroy
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  depends_on = [
    google_project_service.enabled-apis
  ]
}

# Create GCS bucket for Cloud Build logs and build outputs

resource "google_storage_bucket" "cloud-build-logs-artefacts" {
  project                     = google_project.seed.project_id
  name                        = local.cb_artefacts_bucket_name
  location                    = var.gcs_region
  force_destroy               = true
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  depends_on = [
    google_project_service.enabled-apis
  ]
}

# Create Terraform service account

resource "google_service_account" "tf-sa" {
  account_id   = var.tf_sa_name
  display_name = var.tf_sa_name
  project      = google_project.seed.project_id
  depends_on = [
    google_storage_bucket.tf-seed-state-bucket
  ]
}

# Apply IAM roles for the Terraform service account to the root organisation node scope

resource "google_organization_iam_member" "tf-sa-org-iam-roles" {
  for_each = length(var.tf_iam_org_roles) == 0 ? [] : toset(var.tf_iam_org_roles)
  org_id   = var.org_id
  member   = "serviceAccount:${google_service_account.tf-sa.email}"
  role     = each.value
  depends_on = [
    google_service_account.tf-sa
  ]
}

# Apply IAM roles for the Terraform service account to the billing account

resource "google_billing_account_iam_member" "tf-sa-ba-iam-roles" {
  for_each           = length(var.tf_iam_ba_roles) == 0 ? [] : toset(var.tf_iam_ba_roles)
  billing_account_id = var.billing_account_id
  role               = each.value
  member             = "serviceAccount:${google_service_account.tf-sa.email}"
}

# Remove default Billing Account Creator role from the domain if present

resource "null_resource" "remove-domain-billing-creator-role" {
  provisioner "local-exec" {
    command     = "scripts/remove-domain-role.sh"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      ORG_ID     = var.org_id
      ORG_DOMAIN = var.org_domain
      ROLE       = "roles/billing.creator"
      ROLE_NAME  = "Billing Account Creator"
    }
  }
  depends_on = [
    google_organization_iam_member.tf-sa-org-iam-roles
  ]
}

# Remove default Project Creator role from the domain if present

resource "null_resource" "remove-domain-project-creator-role" {
  provisioner "local-exec" {
    command     = "scripts/remove-domain-role.sh"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      ORG_ID     = var.org_id
      ORG_DOMAIN = var.org_domain
      ROLE       = "roles/resourcemanager.projectCreator"
      ROLE_NAME  = "Project Creator"
    }
  }
  depends_on = [
    null_resource.remove-domain-billing-creator-role
  ]
}

# Apply IAM roles for the Terraform service account to the seed project scope

resource "google_project_iam_member" "tf-sa-seed-project-iam-roles" {
  for_each = length(var.tf_iam_project_roles) == 0 ? [] : toset(var.tf_iam_project_roles)
  project  = google_project.seed.id
  member   = "serviceAccount:${google_service_account.tf-sa.email}"
  role     = each.value
  depends_on = [
    google_service_account.tf-sa
  ]
}

# Grant access to GCS bucket used as Terraform remote backend to Terraform & Cloud Build service accounts
# This is required so Cloud Build can successfully initialise the Terraform backend before
# running the remaining Terraform deployment via service account impersonation

resource "google_storage_bucket_iam_member" "sa-gcs-object-admin-tf-sa" {
  bucket = google_storage_bucket.tf-seed-state-bucket.id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.tf-sa.email}"

  depends_on = [
    google_service_account.tf-sa
  ]
}

resource "google_storage_bucket_iam_member" "sa-gcs-object-admin-cb-sa" {
  bucket = google_storage_bucket.tf-seed-state-bucket.id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_project.seed.number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_service_account.tf-sa
  ]
}

# Enable Cloud Build service account to impersonate (i.e. execute as) the Terraform service account

resource "google_service_account_iam_member" "cb-impersonate-tf-sa" {
  service_account_id = google_service_account.tf-sa.id
  member             = "serviceAccount:${google_project.seed.number}@cloudbuild.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  depends_on = [
    google_project_iam_member.tf-sa-seed-project-iam-roles
  ]
}

# Grant access to GCS bucket storing Cloud Build logs and outputs to Terraform & Cloud Build service accounts

resource "google_storage_bucket_iam_member" "sa-artefacts-gcs-object-admin-tf-sa" {
  bucket = google_storage_bucket.cloud-build-logs-artefacts.id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.tf-sa.email}"

  depends_on = [
    google_storage_bucket.cloud-build-logs-artefacts
  ]
}

resource "google_storage_bucket_iam_member" "sa-artefacts-gcs-object-admin-cb-sa" {
  bucket = google_storage_bucket.cloud-build-logs-artefacts.id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_project.seed.number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_storage_bucket.cloud-build-logs-artefacts
  ]
}

# Create an Artifact Registry repo for Cloud Build builder images and build artefacts

resource "google_artifact_registry_repository" "cb-registry" {
  provider      = google-beta
  repository_id = var.artefact_registry_repo_id
  location      = var.default_region
  project       = google_project.registry.project_id
  format        = "DOCKER"
  depends_on = [
    google_project_service.registry-enabled-apis
  ]
}

# Grant read/write access to artefact registry to Terraform & Cloud Build service accounts

resource "google_artifact_registry_repository_iam_member" "artefact_registry_admin_tf_sa" {
  provider   = google-beta
  project    = google_project.registry.project_id
  location   = var.default_region
  repository = var.artefact_registry_repo_id
  role       = "roles/artifactregistry.admin"
  member     = "serviceAccount:${google_service_account.tf-sa.email}"

  depends_on = [
    google_artifact_registry_repository.cb-registry
  ]
}

resource "google_artifact_registry_repository_iam_member" "artefact_registry_read_write_cb_sa" {
  provider   = google-beta
  project    = google_project.registry.project_id
  location   = var.default_region
  repository = var.artefact_registry_repo_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_project.seed.number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_artifact_registry_repository.cb-registry
  ]
}

# Create a cloud source repo for the OPA policy library to be used by Terraform Validator
#  and optionally Forseti

resource "google_sourcerepo_repository" "policy-lib-repo" {
  name    = var.policy_lib_repo_name
  project = google_project.registry.project_id
  depends_on = [
    google_project_service.registry-enabled-apis
  ]
}

# Grant read/write access to the policy lib repo to Terraform & Cloud Build service accounts

resource "google_sourcerepo_repository_iam_member" "policy-lib-repo-read-write-tf-sa" {
  project    = google_project.registry.project_id
  repository = google_sourcerepo_repository.policy-lib-repo.name
  role       = "roles/source.writer"
  member     = "serviceAccount:${google_service_account.tf-sa.email}"

  depends_on = [
    google_sourcerepo_repository.policy-lib-repo
  ]
}

resource "google_sourcerepo_repository_iam_member" "policy-lib-repo-read-write-cb-sa" {
  project    = google_project.registry.project_id
  repository = google_sourcerepo_repository.policy-lib-repo.name
  role       = "roles/source.writer"
  member     = "serviceAccount:${google_project.seed.number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_sourcerepo_repository.policy-lib-repo
  ]
}

# Clone Terraform Cloud Builder repo

resource "null_resource" "clone-terraform-builder-repo" {
  provisioner "local-exec" {
    command     = "scripts/clone-external-git-repo.sh"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      REPO_URL = var.google_bootstrap_repo_url
    }
  }
  depends_on = [
    google_sourcerepo_repository_iam_member.policy-lib-repo-read-write-cb-sa,
    google_sourcerepo_repository_iam_member.policy-lib-repo-read-write-tf-sa
  ]
}

# Build Terraform Cloud Builder image (includes TF and TF Validator)
# and push to gcr.io to create a GCR repo on the seed project

resource "null_resource" "build-terraform-builder-image" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud builds submit $HOME/cloudshell_open/gcp-lz-bootstrap/cloudbuild-builder \
      --config $HOME/cloudshell_open/gcp-lz-bootstrap/cloudbuild-builder/cloudbuild.yaml \
      --substitutions _REPO_REGION=$REPO_REGION,_REPO_PROJECT=$REPO_PROJECT,_REPO_ID=$REPO_ID \
      --project $SEED_PROJ
    EOT
    environment = {
      SEED_PROJ        = local.seed_project_unique_id
      REPO_PROJECT     = local.registry_project_unique_id
      REPO_ID          = var.artefact_registry_repo_id
      TF_VER           = var.terraform_builder_version
      TF_SHASUM        = var.terraform_builder_shasum
      TF_VALIDATOR_VER = var.terraform_validator_version
      REPO_REGION      = var.default_region
    }
  }
  depends_on = [
    null_resource.clone-terraform-builder-repo
  ]
}

# Clone Forseti policy library

resource "null_resource" "clone-policy-lib" {
  provisioner "local-exec" {
    command     = "scripts/clone-external-git-repo.sh"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      REPO_URL = var.policy_lib_repo_url
    }
  }
  depends_on = [
    null_resource.build-terraform-builder-image
  ]
}

# Push policy lib to cloud source repository

resource "null_resource" "push-policy-lib-to-csr" {
  provisioner "local-exec" {
    command = "cd $HOME/policy-library && git remote add google https://source.developers.google.com/p/$REPO_PROJECT/r/$REPO_NAME && git push -u google master"
    environment = {
      REPO_PROJECT = local.registry_project_unique_id
      REPO_NAME    = var.policy_lib_repo_name
    }
  }
  depends_on = [
    null_resource.clone-policy-lib
  ]
}

# Create Cloud Source Repository for landing zone Terraform source 

resource "google_sourcerepo_repository" "tf_lz_source" {
  name    = var.org_phase_repo_name
  project = google_project.seed.project_id
  depends_on = [
    null_resource.push-policy-lib-to-csr
  ]
}

# Grant read/write access to the Terraform source repo to Terraform & Cloud Build service accounts

resource "google_sourcerepo_repository_iam_member" "tf_lz_source_read_write_tf_sa" {
  project    = google_project.seed.project_id
  repository = google_sourcerepo_repository.tf_lz_source.name
  role       = "roles/source.writer"
  member     = "serviceAccount:${google_service_account.tf-sa.email}"

  depends_on = [
    google_sourcerepo_repository.tf_lz_source
  ]
}

resource "google_sourcerepo_repository_iam_member" "tf_lz_source_read_write_cb_sa" {
  project    = google_project.seed.project_id
  repository = google_sourcerepo_repository.tf_lz_source.name
  role       = "roles/source.writer"
  member     = "serviceAccount:${google_project.seed.number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_sourcerepo_repository.tf_lz_source
  ]
}

# ==========================================================================================
# 
# The following section contains Cloud Build trigger resources that are provisioned
# separately based on the 'enable_cb_triggers' boolean variable.
# This enables two separate deployment runs of this Terraform configuration :
# 1. All of the resources up to this point are created first
# 2. Once a manual step has been completed to add a public SSH deploy key to Github, the 
#    second deployment run is executed with the 'enable_cb_triggers' value set to true
# 
# ==========================================================================================

# Conditionally create Cloud Build trigger to plan the core landing zone ORG deployment

resource "google_cloudbuild_trigger" "plan-org-phase" {
  count = var.enable_cb_triggers ? 1 : 0
  name  = "lz-org-terraform-plan"
  trigger_template {
    repo_name   = var.org_phase_repo_name
    branch_name = local.plan_branch_name
  }
  project = google_project.seed.project_id
  substitutions = {
    _BILL_ID                  = var.billing_account_id
    _BRANCH_BASE_NAME         = var.client_short_name
    _CB_ARTEFACT_BUCKET       = "${google_storage_bucket.cloud-build-logs-artefacts.id}"
    _CLONE_TF_REPO_NAME       = var.clone_tf_csr_repo_name
    _ENABLE_CB_TRIGGERS       = true
    _GCS_REGION               = var.gcs_region
    _ORG_ID                   = var.org_id
    _REPO_ID                  = var.artefact_registry_repo_id
    _REPO_PROJECT             = local.registry_project_unique_id
    _REPO_REGION              = var.default_region
    _STATE_FORCE_DESTROY      = false
    _TF_BUCKET                = "${google_storage_bucket.tf-seed-state-bucket.id}"
    _TF_CSR_REPO_NAME         = var.org_phase_repo_name
    _TF_CSR_REPO_PROJ         = "${google_project.seed.project_id}"
    _TF_SA                    = "${google_service_account.tf-sa.email}"
    _WORKLOAD_NETWORK_REGIONS = var.workload_env_subnet_regions
  }
  filename = var.plan_org_cb_job_config
  depends_on = [
    null_resource.push-policy-lib-to-csr
  ]
}

# Conditionally create Cloud Build trigger to apply the core landing zone ORG deployment

resource "google_cloudbuild_trigger" "apply-org-phase" {
  count = var.enable_cb_triggers ? 1 : 0
  name  = "lz-org-terraform-apply"
  trigger_template {
    repo_name   = var.org_phase_repo_name
    branch_name = local.apply_branch_name
  }
  project = google_project.seed.project_id
  substitutions = {
    _BILL_ID                  = var.billing_account_id
    _BRANCH_BASE_NAME         = var.client_short_name
    _CB_ARTEFACT_BUCKET       = "${google_storage_bucket.cloud-build-logs-artefacts.id}"
    _CLONE_TF_REPO_NAME       = var.clone_tf_csr_repo_name
    _ENABLE_CB_TRIGGERS       = true
    _GCS_REGION               = var.gcs_region
    _ORG_ID                   = var.org_id
    _REPO_ID                  = var.artefact_registry_repo_id
    _REPO_PROJECT             = local.registry_project_unique_id
    _REPO_REGION              = var.default_region
    _STATE_FORCE_DESTROY      = false
    _TF_BUCKET                = "${google_storage_bucket.tf-seed-state-bucket.id}"
    _TF_CSR_REPO_NAME         = var.org_phase_repo_name
    _TF_CSR_REPO_PROJ         = "${google_project.seed.project_id}"
    _TF_SA                    = "${google_service_account.tf-sa.email}"
    _WORKLOAD_NETWORK_REGIONS = var.workload_env_subnet_regions
  }
  filename = var.apply_org_cb_job_config
  depends_on = [
    google_cloudbuild_trigger.plan-org-phase
  ]
}

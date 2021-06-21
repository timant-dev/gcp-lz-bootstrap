resource "random_id" "rand_id" {
  byte_length = 4
  #   prefix      = "${var.project_base_name}-"
}

locals {
  unique_bucket_name = "${var.tf_state_bucket_name}-${random_id.rand_id.hex}"
  unique_project_id  = "${var.seed_project_id}-${random_id.rand_id.hex}"
}

resource "google_folder" "bootstrap" {
  display_name = var.parent_folder_name
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "lz" {
  display_name = var.lz_folder_name
  parent       = "organizations/${var.org_id}"
}

resource "google_project" "seed" {
  name                = local.unique_project_id
  project_id          = local.unique_project_id
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

resource "google_storage_bucket" "tf-seed-state-bucket" {
  project                     = google_project.seed.project_id
  name                        = local.unique_bucket_name
  location                    = var.gcs_region
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  #   encryption {
  #
  #   }
  depends_on = [
    google_project_service.enabled-apis
  ]
}

resource "google_service_account" "tf-sa" {
  account_id   = var.tf_sa_name
  display_name = var.tf_sa_name
  project      = google_project.seed.id
  depends_on = [
    google_storage_bucket.tf-seed-state-bucket
  ]
}

resource "google_folder_iam_member" "tf-sa-folder-iam-roles" {
  for_each = length(var.tf_iam_folder_roles) == 0 ? [] : toset(var.tf_iam_folder_roles)
  folder   = google_folder.lz.folder_id
  member   = "serviceAccount:${google_service_account.tf-sa.email}"
  role     = each.value
}

resource "google_storage_bucket_iam_member" "tf-sa-gcs-admin" {
  bucket = google_storage_bucket.tf-seed-state-bucket.id
  member = "serviceAccount:${google_service_account.tf-sa.email}"
  role   = "roles/storage.admin"
}

resource "google_service_account_iam_binding" "cb-impersonate-tf-sa" {
  service_account_id = google_service_account.tf-sa.email
  members            = ["serviceAccount:${google_project.seed.number}@cloudbuild.gserviceaccount.com"]
  role               = "roles/iam.serviceAccountTokenCreator"
}

resource "google_storage_bucket_iam_member" "cb-sa-gcs-admin" {
  bucket = google_storage_bucket.tf-seed-state-bucket.id
  member = "serviceAccount:${google_project.seed.number}@cloudbuild.gserviceaccount.com"
  role   = "roles/storage.admin"
}

output "tf-state-bucket-name" {
  value = google_storage_bucket.tf-seed-state-bucket.id
}

output "cb_logs_bucket_url" {
  value = google_storage_bucket.cloud-build-logs-artefacts.url
}

output "seed_project_id" {
  value = google_project.seed.project_id
}

output "tf_sa_email" {
  value = google_service_account.tf-sa.email
}

output "tf_sa_id" {
  value = google_service_account.tf-sa.id
}

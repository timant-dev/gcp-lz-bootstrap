output "tf-state-bucket-name" {
  value = google_storage_bucket.tf-seed-state-bucket.id
}

output "github_deploy_key_secret_version" {
  value = google_secret_manager_secret_version.github_secret_version.name
}

output "cb_logs_bucket_url" {
  value = google_storage_bucket.cloud-build-logs-artefacts.url
}

output "seed_project_id" {
  value = google_project.seed.project_id
}
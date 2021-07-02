# Landing Zone Bootstrap Steps

Run the following steps to deploy the landing zone bootstrap infrastructure :

## 1. Set default region for Terraform state storage

- This command will configure the region where you wish to locate a GCS storage bucket for Terraform state
- Click the button to paste this to the Cloud Shell command line and add your region e.g. `us-east1`

```sh
export GCS_REGION="" 
```

## 2. Initialise Terraform Variables

- This step inserts the Organisation ID, Billing Account ID and default region into the `terraform.tfvars.example` template. Run this script :

```sh
./init-tfvars.sh
```

## 3. Initialise Terraform

- Once the `terraform.tfvars` file has been generated from the template, initialise Terraform :

```sh
terraform init
```

## 4. Create a new Terraform workspace

- Create a new workspace named __bootstrap__ :

```sh
terraform workspace new bootstrap
```

## 5. Generate a Terraform plan

- Review the plan output before deploying : 

```sh
terraform plan
```

## 6. Deploy the bootstrap resources

- Deploy the Bootstrap infrastructure :

```sh
terraform apply
```

## 7. Update Terraform GCS backend configuration

- This step updates the placeholder value in the Terraform backend configuration with the GCS bucket name just created by the deployment
- Run the following script :

```sh
./init-backend.sh
```

## 8. Migrate Terraform state to GCS backend

- The Terraform deployment created a __state__ file locally on the Cloud Shell VM
- This step will migrate that local state to the newly created GCS bucket in the seed project :

```sh
terraform init -migrate-state
```

## 9. Add a mirrored GitHub repository to provide Cloud Build CI pipeline configuration (MANUAL STEP IN GCP CONSOLE)

- This step comprises creating GCP Cloud Source Repository that __mirrors__ a private Github repository
- Ensure you have a Github machine user account permissioned for access to the private repository
- Sign out of any Github sessions beforehand
- Follow instructions on how to mirror your Github repo here : <https://cloud.google.com/source-repositories/docs/mirroring-a-github-repository#create_a_mirrored_repository> and then return to this tutorial once completed


## 10. Run Terraform to add Cloud Build CI job triggers for next landing zone deployment phase

- Run the following commands passing in a command line variable to enable provisioning of the Cloud Build CI job triggers :

```sh
export REPO_PROJ=$(gcloud projects list --filter='name ~ seed' --format='value(projectId)') && export ORG_REPO=$(gcloud source repos list --format='value(name)' --project=${REPO_PROJ})
```

```sh
terraform plan -var="enable_cb_triggers=true" -var="org_phase_repo_name=${ORG_REPO}}"
```

- Confirm the plan output and then apply the changes :

```sh
terraform apply -var="enable_cb_triggers=true" -var="org_phase_repo_name=${ORG_REPO}}"
```

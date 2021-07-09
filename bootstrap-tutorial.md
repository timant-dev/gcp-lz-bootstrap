# Landing Zone Bootstrap Steps

## Bootstrap Steps

This guide walks you through each step to set up the minimal bootstrap infrastructure that will enable the core GCP landing zone to be provisioned in a subsequent phase.

- In each step, click the 'Copy to Cloud Shell' button next to each command to paste directly into the terminal.
- Hit the **Start** button to begin

## 0. Set landing zone customer short name

- Sets an environment variable to be used to link to customer-specific Terraform source repo branches

```sh
export CLIENT_NAME="client-abc"
```

## 1. Set GCS region for Terraform state storage bucket and landing zone resource default region

- This command will configure the region where you wish to locate a GCS storage bucket for Terraform state
- Also a default region to use for other landing zone resources
- Edit to add the GCS region e.g. a single region like `us-east1` or multi-region such as `EU`

```sh
export GCS_REGION="us-east1" && export DEFAULT_REGION="us-east1"
```

For GCS region, select one of the following :

- __North America__
   - NORTHAMERICA-NORTHEAST1 : Montréal
   - US-CENTRAL1 : Iowa
   - US-EAST1 : South Carolina
   - US-EAST4 : Northern Virginia
   - US-WEST1 : Oregon
   - US-WEST2 : Los Angeles
   - US-WEST3 : Salt Lake City
   - US-WEST4 : Las Vegas
- __South America__		
   - SOUTHAMERICA-EAST1 : São Paulo
- __Europe__
   - EUROPE-CENTRAL2 : Warsaw
   - EUROPE-NORTH1 : Finland
   - EUROPE-WEST1 : Belgium
   - EUROPE-WEST2 : London
   - EUROPE-WEST3 : Frankfurt
   - EUROPE-WEST4 : Netherlands
   - EUROPE-WEST6 : Zürich
- __Asia__
   - ASIA-EAST1 : Taiwan
   - ASIA-EAST2 : Hong Kong
   - ASIA-NORTHEAST1 : Tokyo
   - ASIA-NORTHEAST2 : Osaka
   - ASIA-NORTHEAST3 : Seoul
   - ASIA-SOUTH1 : Mumbai
   - ASIA-SOUTH2 : Delhi
   - ASIA-SOUTHEAST1 : Singapore
   - ASIA-SOUTHEAST2 : Jakarta
- __Australia__
   - AUSTRALIA-SOUTHEAST1 : Sydney
   - AUSTRALIA-SOUTHEAST2 : Melbourne
- __Multi-regions__
   - ASIA : Data centers in Asia
   - EU : Data centers within member states of the European Union (excludes London & Zurich)
   - US : Data centers in the United States
- __Dual-regions__
   - ASIA1 : ASIA-NORTHEAST1 and ASIA-NORTHEAST2
   - EUR4 : EUROPE-NORTH1 and EUROPE-WEST4
   - NAM4 : US-CENTRAL1 and US-EAST1

For default landing zone region, select one of the following :
- __North America__
   - northamerica-northeast1
   - us-central1
   - us-east1
   - us-east4
   - us-west1
   - us-west2
   - us-west3
   - us-west4
- __South America__	
   - southamerica-east1
- __Europe__
   - europe-central2
   - europe-north1
   - europe-west1
   - europe-west2
   - europe-west3
   - europe-west4
   - europe-west6
- __Asia__
   - asia-east1
   - asia-east2
   - asia-northeast1
   - asia-northeast2
   - asia-northeast3
   - asia-south1
   - asia-south2
   - asia-southeast1
   - asia-southeast2
- __Australia__
   - australia-southeast1
   - australia-southeast2

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
terraform plan -var="enable_cb_triggers=true" -var="org_phase_repo_name=${ORG_REPO}"
```

- Confirm the plan output and then apply the changes :

```sh
terraform apply -var="enable_cb_triggers=true" -var="org_phase_repo_name=${ORG_REPO}"
```

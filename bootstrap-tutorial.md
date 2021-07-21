# Landing Zone Bootstrap Steps

## Bootstrap Steps

This guide walks you through each step to set up the minimal bootstrap infrastructure that will enable the core GCP landing zone to be provisioned in a subsequent phase.

- In each step, click the 'Copy to Cloud Shell' button next to each command to paste directly into the terminal.
- Hit the **Start** button to begin

## 0. Set variables for Github landing zone repository

```sh
export GITHUB_BOT_USER="github-machine-user-email"
```

```sh
export GITHUB_BOT_NAME="github-bot-name"
```

```sh
export GITHUB_URL="https://github.com/"
```

## 1. Set landing zone customer short name

- Sets an environment variable to be used to link to customer-specific Terraform source repo branches

```sh
export CLIENT_NAME="client-abc"
```

## 2. Set GCS region for Terraform state storage bucket

- This command will configure the region where you wish to locate a GCS storage bucket for Terraform state
- Edit to add the GCS region e.g. a single region like `us-east1` or multi-region such as `EU`

```sh
export GCS_REGION="us-east1"
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

## 3. Set landing zone default region

```sh
export DEFAULT_REGION="us-east1"
```

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

## 4. Initialise Terraform Variables

- This step inserts the Organisation ID, Billing Account ID and default region into the `terraform.tfvars.example` template. Run this script :

```sh
./init-tfvars.sh
```

## 5. Initialise Terraform

- Once the `terraform.tfvars` file has been generated from the template, initialise Terraform :

```sh
terraform init
```

## 6. Create a new Terraform workspace

- Create a new workspace named __bootstrap__ :

```sh
terraform workspace new bootstrap
```

## 7. Generate a Terraform plan

- Review the plan output before deploying : 

```sh
terraform plan
```

## 8. Deploy the bootstrap resources

- Deploy the Bootstrap infrastructure :

```sh
terraform apply -auto-approve
```

## 9. Update Terraform GCS backend configuration

- This step updates the placeholder value in the Terraform backend configuration with the GCS bucket name just created by the deployment
- Run the following script :

```sh
./init-backend.sh
```

## 10. Migrate Terraform state to GCS backend

- The Terraform deployment created a __state__ file locally on the Cloud Shell VM
- This step will migrate that local state to the newly created GCS bucket in the seed project :

```sh
terraform init -migrate-state
```

## 11. Clone a private GitHub repository to provide Cloud Build CI pipeline configuration

- This step comprises cloning a private Github repository & pushing it into a GCP Cloud Source Repository
- Ensure you have a Github machine user account permissioned for access to the private repository

- First configure the Cloudshell user credentials to connect to the private Github repo

```sh
ssh-keygen -t rsa -b 4096 -N "" -q -C "${GITHUB_BOT_USER}" -f ~/.ssh/id_github
```

```sh
ssh-keyscan -t rsa github.com 2>&1 | tee ~/.ssh/known_hosts && cat ssh_config_template >~/.ssh/config
```

- Next configure the Cloudshell git session

```sh
git config --global user.email "${GITHUB_BOT_USER}" && git config --global user.name "${GITHUB_BOT_NAME}"
```

```sh
git config --global credential.https://source.developers.google.com.helper gcloud.sh && export WORKDIR=${PWD}
```

## 12. Add the public SSH key as a deploy key on the Github repo

- Copy the generated public key and add it as a deploy key on the private Github repo
- See instructions here : <https://docs.github.com/en/developers/overview/managing-deploy-keys#deploy-keys>
- Once you've added the deploy key to the Github repo, return to this tutorial for the next step


## 13. Clone the Github repo 

```sh
export GITHUB_SSH_URL=$(echo ${GITHUB_URL} | sed 's/https:\/\/github.com\//git\@github.com:/;s/$/.git/')
```

```sh
export SEED_PROJ=$(terraform output -raw seed_project_id) && export GITHUB_REPO_NAME=$(basename ${GITHUB_URL})
```

```sh
cd ${HOME} && git clone ${GITHUB_SSH_URL}
```

## 14. Push the cloned Github repo into a Cloud Source Repository

- Define a remote that points to the empty CSR created by the Bootstrap Terraform configuration and push the cloned repo 

```sh
cd ${HOME}/${GITHUB_REPO_NAME}
```

```sh
git remote add google https://source.developers.google.com/p/${SEED_PROJ}/r/${GITHUB_REPO_NAME}
```

```sh
git push --all google
```

```sh
git checkout --track remotes/origin/develop && git push google
```

## 15. Run Terraform to add Cloud Build CI job triggers for next landing zone deployment phase

- Invoke Terraform to provision the landing zone Cloud Build job triggers and complete the Bootstrap phase

```sh
cd ${WORKDIR} && terraform apply -auto-approve -var="enable_cb_triggers=true"
```

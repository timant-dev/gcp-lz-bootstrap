### Landing Zone Bootstrap Steps

Run the following steps to deploy the landing zone bootstrap infrastructure :

#### 1. Set default region for Terraform state storage

- This command will configure the region where you wish to locate a GCS storage bucket for Terraform state
- Click the button to paste this to the Cloud Shell command line and add your region e.g. `us-east1`

```sh
export GCS_REGION="" 
```

#### 2. Initialise Terraform Variables

- This step inserts the Organisation ID, Billing Account ID and default region into the `terraform.tfvars.example` template. Run this script :

```sh
./init-tfvars.sh
```

#### 3. Initialise Terraform

- Once the `terraform.tfvars` file has been generated from the template, initialise Terraform :

```sh
terraform init
```

#### 4. Create a new Terraform workspace

- Create a new workspace named __bootstrap__ :

```sh
terraform workspace new bootstrap
```

#### 5. Generate a Terraform plan

- Review the plan output before deploying : 

```sh
terraform plan
```

#### 6. Deploy the bootstrap resources

- Deploy the Bootstrap infrastructure :

```sh
terraform apply
```

#### 7. Update Terraform GCS backend configuration

- This step updates the placeholder value in the Terraform backend configuration with the GCS bucket name just created by the deployment
- Run the following script :

```sh
./init-backend.sh
```

#### 8. Migrate Terraform state to GCS backend

- The Terraform deployment created a __state__ file locally on the Cloud Shell VM
- This step will migrate that local state to the newly created GCS bucket in the seed project :

```sh
terraform init -migrate-state
```
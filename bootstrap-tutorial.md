### Landing Zone Bootstrap Steps

Run the following steps to deploy the landing zone bootstrap infrastructure :

#### 1. Initialise Terraform Variables

- This step inserts the Organisation ID, Billing Account ID and default region into the `terraform.tfvars.example` template. Run this script :

```sh
./init-tfvars.sh
```

#### 2. Initialise Terraform

- Once the `terraform.tfvars` file has been generated from the template, initialise Terraform :

```sh
terraform init
```

#### 3. Create a new Terraform workspace

- Create a new workspace named __bootstrap__ :

```
terraform workspace new bootstrap
```

#### 4. Generate a Terraform plan

- Review the plan output before deploying : 

```
terraform plan
```

#### 5. Deploy the bootstrap resources

- Deploy the Bootstrap infrastructure :

```
terraform apply
```

#### 6. Update Terraform GCS backend configuration

- This step updates the placeholder value in the Terraform backend configuration with the GCS bucket name just created by the deployment
- Run the following script :

```
./init-backend.sh
```

#### 7. Migrate Terraform state to GCS backend

- The Terraform deployment created a __state__ file locally on the Cloud Shell VM
- This step will migrate that local state to the newly created GCS bucket in the seed project :

```
terraform init -migrate-state
```
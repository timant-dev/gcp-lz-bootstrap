#### Landing Zone Bootstrap Steps

__1. Terraform Variables Initialisation__

- Run the `init-tfvars.sh` script to initialise a `terraform.tfvars` variable values file from the `terraform.tfvars.example` template
- The script will populate the Organisation ID and Billing Account ID using `gcloud` commands and interpolate those values into the template output

__2. Executing Terraform Configuration__

- Once the `terraform.tfvars` file has been generated from the template, the usual Terraform steps can be executed as followed :
   - `terraform init`
   - `terraform workspace new bootstrap` - Creates a workspace named `bootstrap`
   - `terraform plan`
   - `terraform apply` 

__3. Migrate Local Terraform State to Remote Backend__

After the Terraform bootstrap provisioning is complete, the Terraform state will reside locally in the home directory of the Cloud Shell VM. 

Therefore, the next step is to migrate that local state to the newly created GCS bucket in the `lz-seed` project.

To do this, first run the `init-backend.sh` script that will extract the GCS bucket name from the Terraform state outputs and interpolate it into the `backend.tf.example` template to produce a `backend.tf` configuration file.

Next run the following Terraform command to migrate the local state to the new backend :

```
terraform init -migrate-state
```
## GCP Landing Zone Bootstrap 

This repository provides a Terraform implementation of a simple GCP landing zone bootstrap configuration. The purpose of the bootstapping is to provide a small seed project starting point from which the entirety of the core landing zone infrastructure can then be subsequently provisioned.

### Bootstrap components

The components that are provisioned include :

- Two folders directly under the root organization node : `bootstrap` and `lz`
- A seed project in the `bootstrap` folder : `bootstrap/lz-seed`
- A Google Cloud Storage (GCS) bucket in the `lz-seed` project to hold the Terraform state
- A service account that will be used to run the Terraform provisioning of the core landing zone infrastructure : `terraform-core`
- A list of enabled APIs in the `lz-seed` project :
   - cloudapis.googleapis.com
   - cloudasset.googleapis.com
   - cloudbilling.googleapis.com
   - cloudbuild.googleapis.com
   - cloudresourcemanager.googleapis.com,
   - containerregistry.googleapis.com,
   - iam.googleapis.com,
   - iamcredentials.googleapis.com,
   - serviceusage.googleapis.com,
   - storage-api.googleapis.com,
   - storage-component.googleapis.com,
   - storage.googleapis.com
- A number of IAM roles assigned to the Terraform service account at the organisation, folder and GCS bucket level :
   - roles/billing.user
   - roles/resourcemanager.folderAdmin
   - roles/resourcemanager.projectCreator
   - roles/compute.admin
   - roles/serviceusage.serviceUsageAdmin
- The __Cloud Build service account__ in the `lz-seed` project is also granted the IAM `roles/iam.serviceAccountTokenCreator` role to enable it to impersonate the Terraform service account

### Running the bootstrap configuration

For context, prior to executing this GCP landing zone bootstrap configuration there are no folders or projects in the GCP space for the specified organisation. There is only an organisation node, an assigned billing account and a small number of groups with Organisation Admin or Billing Admin IAM roles.

As such, the bootstrap code must be executed by a user identity who is a member of the GCP organisation admin group.

__1. Cloud Shell Terraform Execution Environment__

[Google Cloud Shell](https://cloud.google.com/shell/docs/using-cloud-shell) provides a convenient, secure and **serverless** solution for running the bootstrap Terraform configuration.

Cloud Shell spins up an ephemeral VM with a 5GB home directory that persists across sessions. The VM comes with a range of pre-installed tools and packages such as Cloud SDK (`gcloud` CLI), Docker, Minikube, MySQL, `kubectl` and Terraform. This means it provides an ideal remote execution environment for Terraform because the user credentials are handled by the GCP login and Cloud Shell ensures that no additional set-up is required to provide credentials to Terraform.

__2. Open in Cloud Shell Easy Access Feature__

Additionally, Cloud Shell provides the [Open in Cloud Shell](https://cloud.google.com/shell/docs/open-in-cloud-shell) URL feature that supports a parameterised URL format to initiate a Cloud Shell session and optionally clone a git repository (GitHub & BitBucket supported currently) to the home directory of the Cloud Shell VM.

Using an Open in Cloud Shell URL is a convenient way to make initialising the bootstrap process on a Cloud Shell VM a one-click step with no additional infrastructure provisioning required.

It also means that the bootstrap process itself can be driven entirely by Terraform with no need for scripted `glcoud` commands.

See below for a sample Open in Cloud Shell URL that instructs Cloud Shell to clone this repo and select the `main` branch :

```
https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/timantrobus/gcp-lz-bootstrap&cloudshell_git_branch=main
```

__3. Terraform Variables Initialisation__

- Having started an authenticated Cloud Shell session using the Open in Cloud Shell URL, the user then needs to run the `init-tfvars.sh` script to initialise a `terraform.tfvar` variable values file from the `terraform.tfvars.example` template
- The script will populate the Organisation ID and Billing Account ID using `gcloud` commands and interpolate those values into the template output

__4. Executing Terraform Configuration__

- Once the `terraform.tfvars` file has been generated from the template, the usual Terraform steps can be executed as followed :
   - `terraform init`
   - `terraform workspace new bootstrap` - Creates a workspace named `bootstrap`
   - `terraform plan`
   - `terraform apply` 

__5. Migrate Local Terraform State to Remote Backend__

After the Terraform bootstrap provisioning is complete, the Terraform state will reside locally in the home directory of the Cloud Shell VM. 

Therefore, the next step is to migrate that local state to the newly created GCS bucket in the `lz-seed` project.

To do this, first run the `init-backend.sh` script that will extract the GCS bucket name from the Terraform state outputs and interpolate it into the `backend.tf.example` template to produce a `backend.tf` configuration file.

Next run the following Terraform command to migrate the local state to the new backend :

```
terraform init -migrate-state
```
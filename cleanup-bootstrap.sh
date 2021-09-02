#!/bin/bash

# Use this script to quickly teardown bootstrap resources and have a clean slate to rebuild
# Pre-req: you might need to run "chmod +x" on this file to make it executable.

terraform destroy #tearsdown bootstrap resources created by terraform
rm bootstrap.tfplan # deletes terraform plan
rm -Rf terraform.tf* #removes terraform.tvars & stated
rm backend.tf #removes updated backend config
cat /dev/null > .terraform/terraform.tfstate #purges content in local state file for new boostrap run of terraform init
cat /dev/null > .terraform/environment #purges workspace data
rm -Rf ~/.ssh/* #purges ssh keys generated
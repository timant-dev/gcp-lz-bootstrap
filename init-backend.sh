#!/bin/bash
set -e
echo "Updating Terraform GCS backend configuration with state bucket name..."
export BUCKET_NAME=$(terraform output -raw tf-state-bucket-name)
if [ -z "${BUCKET_NAME}" ]
then
  echo "ERROR : GCS bucket name not populated"
  exit 1
fi
sed -i.bak -e "s/BUCKET_NAME_PLACEHOLDER/${BUCKET_NAME}/" ${PWD}/backend.tf.example
mv ${PWD}/backend.tf.example ${PWD}/backend.tf
if [ -f "${PWD}/backend.tf" ]
then
  echo "Generated backend.tf file with updated GCS bucket name"
  cat ${PWD}/backend.tf
else
  echo "ERROR : backend.tf file not generated successfully"
  exit 1
fi
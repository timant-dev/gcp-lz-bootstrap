#!/bin/bash
set -e
echo "Interpolating organisation ID, billing account ID and default region into Terraform variables template..."
export ORG_ID=$(gcloud organizations list --format='value(ID)')
export BILL_ID=$(gcloud alpha billing accounts list --format='value(ACCOUNT_ID)' --filter='OPEN=True')
export REGION=$(gcloud config get-value compute/region)
if [[ (-z "${ORG_ID}") || (-z "${BILL_ID}") || (-z "${REGION}") ]]
then
  echo "ERROR : Organisation ID, Billing Account ID or default region not populated"
  exit 1
fi

sed -i.bak "s/XXXXXX/${ORG_ID}/;s/ZZZZZZ/${BILL_ID}/;s/YYYYYY/${REGION}/" ${PWD}/terraform.tfvars.example
mv ${PWD}/terraform.tfvars.example ${PWD}/terraform.tfvars
if [ -f "${PWD}/terraform.tfvars" ]
then
  echo "Generated terraform.tfvars file with organisation ID, billing account ID and region"
  head -3 ${PWD}/terraform.tfvars
else
  echo "ERROR : terraform.tfvars file not generated successfully"
  exit 1
fi

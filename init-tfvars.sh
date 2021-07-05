#!/bin/bash
set -e
echo "Interpolating organisation ID, domain, billing account ID and default region into Terraform variables template..."
export ORG_ID=$(gcloud organizations list --format='value(ID)')
export ORG_DOMAIN=$(gcloud organizations list --format='value(displayName)')
export BILL_ID=$(gcloud alpha billing accounts list --format='value(ACCOUNT_ID)' --filter='OPEN=True')
export REGION=${GCS_REGION}
if [[ (-z "${ORG_ID}") || (-z "${BILL_ID}") || (-z "${REGION}") || (-z "${ORG_DOMAIN") ]]
then
  echo "ERROR : Organisation ID, Domain, Billing Account ID or default region not populated"
  exit 1
fi

sed -i.bak "s/XXXXXX/${ORG_ID}/;s/ZZZZZZ/${BILL_ID}/;s/YYYYYY/${REGION}/;s/WWWWWW/${ORG_DOMAIN}" ${PWD}/terraform.tfvars.example
mv ${PWD}/terraform.tfvars.example ${PWD}/terraform.tfvars
if [ -f "${PWD}/terraform.tfvars" ]
then
  echo "Generated terraform.tfvars file with organisation ID, domain, billing account ID and region"
  head -3 ${PWD}/terraform.tfvars
else
  echo "ERROR : terraform.tfvars file not generated successfully"
  exit 1
fi

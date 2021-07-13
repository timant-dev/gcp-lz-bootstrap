#!/bin/bash
set -e
echo "Interpolating organisation ID, domain, billing account ID and default region into Terraform variables template..."
export CLIENT_SHORT_NAME=${CLIENT_NAME}
export ORG_ID=$(gcloud organizations list --format='value(ID)')
export ORG_DOMAIN=$(gcloud organizations list --format='value(displayName)')
export BILL_ID=$(gcloud alpha billing accounts list --format='value(ACCOUNT_ID)' --filter='OPEN=True')
export LZ_GCS_REGION=${GCS_REGION}
export LZ_DEFAULT_REGION=${DEFAULT_REGION}
if [[ (-z "${CLIENT_SHORT_NAME}") || 
      (-z "${ORG_ID}") || 
      (-z "${BILL_ID}") || 
      (-z "${LZ_GCS_REGION}") || 
      (-z "${LZ_DEFAULT_REGION}") || 
      (-z "${ORG_DOMAIN}") ]]
then
  echo "ERROR : Client name, Organisation ID, Domain, Billing Account ID or region values not populated"
  exit 1
fi

sed -i.bak "s/AAAAAA/${CLIENT_SHORT_NAME}/;s/BBBBBB/${LZ_DEFAULT_REGION}/;s/XXXXXX/${ORG_ID}/;s/ZZZZZZ/${BILL_ID}/;s/YYYYYY/${LZ_GCS_REGION}/;s/WWWWWW/${ORG_DOMAIN}/" ${PWD}/terraform.tfvars.example
mv ${PWD}/terraform.tfvars.example ${PWD}/terraform.tfvars
if [ -f "${PWD}/terraform.tfvars" ]
then
  echo "Generated terraform.tfvars file with client name, organisation ID, domain, billing account ID and region values"
  head -3 ${PWD}/terraform.tfvars
else
  echo "ERROR : terraform.tfvars file not generated successfully"
  exit 1
fi

#!/bin/bash
set -e

echo "Generating Terraform tfvars file..."
export CLIENT_SHORT_NAME=${CLIENT_NAME}
export ORG_ID=${ORG_ID}
export ORG_DOMAIN=${ORG_DOMAIN}
export BILL_ID=${BILL_ID}
export LZ_GCS_REGION=${GCS_REGION}
export LZ_DEFAULT_REGION=${DEFAULT_REGION}

if [[ (-z "${CLIENT_SHORT_NAME}") || 
      (-z "${ORG_ID}") || 
      (-z "${ORG_DOMAIN}") ||       
      (-z "${BILL_ID}") || 
      (-z "${LZ_GCS_REGION}") || 
      (-z "${LZ_DEFAULT_REGION}") ||
      (-z "${WORKLOAD_NETWORK_REGIONS}") ]]
then
  echo "ERROR : One or more variables not populated"
  exit 1
fi

cat > ${PWD}/terraform.tfvars <<EOL
org_id = "${ORG_ID}"
org_domain = "${ORG_DOMAIN}"
billing_account_id = "${BILL_ID}"
client_short_name = "${CLIENT_SHORT_NAME}"
gcs_region = "${LZ_GCS_REGION}"
default_region = "${LZ_DEFAULT_REGION}"
workload_env_subnet_regions = "${WORKLOAD_NETWORK_REGIONS}"
EOL

if [ -f "${PWD}/terraform.tfvars" ]
then
  echo "Generated terraform.tfvars file successfully"
  cat ${PWD}/terraform.tfvars
else
  echo "ERROR : terraform.tfvars file not generated successfully"
  exit 1
fi

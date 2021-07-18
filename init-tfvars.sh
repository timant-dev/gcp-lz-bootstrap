#!/bin/bash
set -e

echo "Generating Terraform tfvars file..."
export CLIENT_SHORT_NAME=${CLIENT_NAME}
export ORG_ID=$(gcloud organizations list --format='value(ID)')
export ORG_DOMAIN=$(gcloud organizations list --format='value(displayName)')
export BILL_ID=$(gcloud alpha billing accounts list --format='value(ACCOUNT_ID)' --filter='OPEN=True')
export LZ_GCS_REGION=${GCS_REGION}
export LZ_DEFAULT_REGION=${DEFAULT_REGION}
ssh-keygen -t ed25519 -N '' -f id_lz_github_bot_ed25519 -C ${GITHUB_BOT_USER}
export GITHUB_DEPLOY_KEY=$(cat ${HOME}/id_lz_github_bot_ed25519)
export GITHUB_REPO_NAME=$(basename ${GITHUB_URL}) && \
export GITHUB_SSH_URL=$(echo ${GITHUB_URL} | sed 's/https:\/\/github.com\//git\@github.com:/;s/$/.git/')

if [[ (-z "${CLIENT_SHORT_NAME}") || 
      (-z "${ORG_ID}") || 
      (-z "${ORG_DOMAIN}") ||       
      (-z "${BILL_ID}") || 
      (-z "${LZ_GCS_REGION}") || 
      (-z "${LZ_DEFAULT_REGION}") || 
      (-z "${GITHUB_DEPLOY_KEY}") ||
      (-z "${GITHUB_REPO_NAME}") ||      
      (-z "${GITHUB_SSH_URL}") ]]
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
github_deploy_key = "${GITHUB_DEPLOY_KEY}"
github_terraform_repo_name = "${GITHUB_REPO_NAME}"
github_terraform_repo_url = "${GITHUB_SSH_URL}"
EOL

if [ -f "${PWD}/terraform.tfvars" ]
then
  echo "Generated terraform.tfvars file successfully"
  cat ${PWD}/terraform.tfvars
else
  echo "ERROR : terraform.tfvars file not generated successfully"
  exit 1
fi

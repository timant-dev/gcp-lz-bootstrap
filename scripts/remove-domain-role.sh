#! /bin/bash

# Checks for presence of specified IAM role on the provided domain
# If the role is present then it is removed. Otherwise this step is a no-op

DOMAIN_ROLE=$(gcloud organizations get-iam-policy ${ORG_ID} \
--flatten='bindings[].members[]' \
--filter="bindings.members ~ ^domain AND bindings.role=${ROLE}" \
--format='value(bindings.role)')
if [[ "${DOMAIN_ROLE}" =~ "${ROLE}" ]]
then
  echo "${DOMAIN_ROLE} is present on ${ORG_DOMAIN}. Removing this role..."
  gcloud organizations remove-iam-policy-binding ${ORG_ID} \
  --member="domain:${ORG_DOMAIN}" \
  --role="${ROLE}"
else
  echo "${ROLE_NAME} role not present on domain ${ORG_DOMAIN}. Skipping deletion of this role"
fi

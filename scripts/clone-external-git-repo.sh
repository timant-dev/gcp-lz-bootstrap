#! /bin/bash

# Checks if a local clone of the external repository already exists and deletes it if found.
# Clones external repository into specified directory

if [[ (-z ${WORKDIR}) || (-z ${REPO_URL}) ]]
then
  echo "ERROR : WORKDIR and REPO_URL variables must be populated"
  exit 1
fi

export REPO_NAME=$(basename "${REPO_URL}" .git)
cd ${WORKDIR}
if [[ -d "${REPO_NAME}" ]]
then
  echo "A copy of repo ${REPO_NAME} already exists locally. Will delete it and clone latest version..."
  rm -rf ${REPO_NAME}
fi
git clone ${REPO_URL}
exit 0

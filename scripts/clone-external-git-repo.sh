#! /bin/bash

# Checks if a local clone of the external repository already exists and deletes it if found.
# Clones external repository into specified directory

[[ -z "${REPO_URL}" ]] && {
  echo "ERROR : REPO_URL variable must be populated"
  exit 1
}

export REPO_NAME=$(basename "${REPO_URL}" .git)
cd ${HOME}
if [[ -d "${REPO_NAME}" ]]
then
  echo "A copy of repo ${REPO_NAME} already exists locally. Will delete it and clone latest version..."
  rm -rf ${REPO_NAME}
fi
git clone ${REPO_URL}
exit 0

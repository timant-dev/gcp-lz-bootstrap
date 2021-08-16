#!/bin/bash

set -eo pipefail

# Check two arguments are provided - one for env file and other for command
if [ $# -lt 2 ]; then
  printf "Usage : $0 arg1 arg2\n"
  printf "Options: 
    arg1 = config file 
    arg2 = 1..7.
        1 = Generate terraform.tfvar file
        2 = Initialize terraform and generate plan"
  exit
fi

STEP_DONE="DONE!\n"
STEP_SUCCESS="SUCCESS!\n"
STEP_FAIL="FAIL!\n"

# Function to return the current time
timestamp()
{
    date +"%Y-%m-%d %T"
    # usage printf "$(timestamp): 0-1: Checking client log file exist ..."
}

printf "\n>>>>>>>>>> RUNNING: STEP 0 - Source config file and check log file.\n\n"
printf "$(timestamp) [0-0]: Sourcing environment variables from .conf file..." 
source $1 # Source config file
printf $STEP_DONE; sleep 2

printf "$(timestamp) [0-1]: Checking client log file exist ..."
if [[ -f $LOG_FILE_PATH ]]
then
    printf "YES! - ${LOG_FILE_PATH}\n"
else
    printf "NO!\n"
    printf "$(timestamp) [0-2]: Creating log file..."
    touch $LOG_FILE_PATH
    printf "${LOG_FILE_PATH} created successfully!\n"
fi
sleep 2

# Function to check file exists and prints outcome
check_file_exists()
{
    local file="$1"
    local number="$2"
    
    if [ -f $file ]
    then
        printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH
    else
        printf $STEP_FAIL | tee -a $LOG_FILE_PATH
        printf "$(timestamp) [ERROR]: $file file is missing. Execute step #$number.\n" | tee -a $LOG_FILE_PATH
        exit 1
    fi
}

# code block #4 update and migrate backend

# code block #5 gen and output ssh key

# code block #6 clone github repo, push cloned repo into cloud source repo

# code block #7 run terraform to add cloud build triggers

case $2 in
1) # Generate terraform.tfvar file. Takes conf as input.
    printf "\n>>>>>>>>>> RUNNING: STEP #1 - Intialize terraform variables and generate var file.\n\n" | tee -a $LOG_FILE_PATH
    printf "$(timestamp) [1-1]: Initialising terraform variables..." | tee -a $LOG_FILE_PATH
    if [[ (-z "${CLIENT_SHORT_NAME}") || 
        (-z "${ORG_ID}") || 
        (-z "${ORG_DOMAIN}") ||       
        (-z "${BILL_ID}") || 
        (-z "${GCS_REGION}") || 
        (-z "${DEFAULT_REGION}") ||
        (-z "${WORKLOAD_NETWORK_REGIONS}") 
    ]]
    then
    printf $STEP_FAIL | tee -a $LOG_FILE_PATH
    printf "$(timestamp) [ERROR]: One or more variables not populated. Check config file.\n" | tee -a $LOG_FILE_PATH
    exit 1
    fi
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 2
    sleep 2

    printf "$(timestamp) [1-2]: Generating terraform.tfvars file..." | tee -a $LOG_FILE_PATH

    cat > ${PWD}/terraform.tfvars <<EOL
    client_short_name = "${CLIENT_SHORT_NAME}"
    org_id = "${ORG_ID}"
    org_domain = "${ORG_DOMAIN}"
    billing_account_id = "${BILL_ID}"
    gcs_region = "${GCS_REGION}"
    default_region = "${DEFAULT_REGION}"
    workload_env_subnet_regions = "${WORKLOAD_NETWORK_REGIONS}" 
EOL

    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [1-3]: Review terraform.tfvar contents below before proceeding to next step:\n\n"
    cat ${PWD}/terraform.tfvars
    printf "\n\n"; sleep 1
;;

2) # Initialize terraform

    printf "\n>>>>>>>>>> RUNNING: STEP #2 - Initialize terraform, create workspace and plan.\n\n" | tee -a $LOG_FILE_PATH
    printf "$(timestamp) [2-1]: Checking terraform.tfvars file exists..." | tee -a $LOG_FILE_PATH

    check_file_exists "${PWD}/terraform.tfvars" "1"

    # if [ -f "${PWD}/terraform.tfvars" ]
    # then
    # printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH
    # else
    # printf $STEP_FAIL | tee -a $LOG_FILE_PATH
    # printf "$(timestamp) [ERROR]: Terraform.tfvars file is missing. Repeat step 1.\n" | tee -a $LOG_FILE_PATH
    # exit 1
    # fi

    printf "$(timestamp) [2-2]: Initializing terraform..." | tee -a $LOG_FILE_PATH
    terraform init 2>&1 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [2-3]: Create new terraform workspace 'bootstrap'..." | tee -a $LOG_FILE_PATH
    set +e # Skip warning message about existing workspace
    terraform workspace new bootstrap 1>&2 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [2-4]: Format terraform files and validate..." | tee -a $LOG_FILE_PATH
    terraform fmt 2>&1 >> $LOG_FILE_PATH

    set -e # Exit on error
    terraform validate 1>&2 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [2-5]: Generate terraform plan..." | tee -a $LOG_FILE_PATH
    if [ -f "${PWD}/$TF_PLAN" ]
    then
        printf "Found existing plan! Replacing..." | tee -a $LOG_FILE_PATH
        rm $TF_PLAN
    fi
    
    terraform plan -out=$TF_PLAN 2>&1 >> $LOG_FILE_PATH
    #printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH

    printf "\nReview the generated plan before deploying. Run 'terraform show bootstrap.tfplan'.\n\n"
    sleep 2
;;

3) # Deploy the bootstrap infrastructure
    printf "\n>>>>>>>>>> RUNNING: STEP #3 - Deploy bootstrap resources.\n\n" | tee -a $LOG_FILE_PATH
    printf "$(timestamp) [3-1]: Checking $TF_PLAN exists..." | tee -a $LOG_FILE_PATH

    check_file_exists "${PWD}/$TF_PLAN" "2"

    printf "$(timestamp) [3-2]: Deploying the bootstrap infrastructure..." | tee -a $LOG_FILE_PATH
    set -e # Exit on error
    terraform apply $TF_PLAN -auto-approve 2>&1 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [3-3]: Review terraform output below: \n\n"
    terraform show output; sleep 1
;;


4) # Update and migrate terraform state to GCS backend
    
    set -e # Toggle to exit on error

    BUCKET_NAME=$(terraform output -raw tf-state-bucket-name)

    # echo "Updating Terraform GCS backend configuration with state bucket name..."
    # export BUCKET_NAME=$(terraform output -raw tf-state-bucket-name)
    # if [ -z "${BUCKET_NAME}" ]
    # then
    #     echo "ERROR : GCS bucket name not populated"
    #     exit 1
    # fi
    # sed -i.bak -e "s/BUCKET_NAME_PLACEHOLDER/${BUCKET_NAME}/" ${PWD}/backend.tf.example
    # mv ${PWD}/backend.tf.example ${PWD}/backend.tf
    # if [ -f "${PWD}/backend.tf" ]
    # then
    #     echo "Generated backend.tf file with updated GCS bucket name"
    #     cat ${PWD}/backend.tf
    # else
    #     echo "ERROR : backend.tf file not generated successfully"
    #     exit 1
    # fi
    
    printf "\n>>>>>>>>>> RUNNING: STEP #4 - Update and migrate terraform state to GCS backend.\n\n" | tee -a $LOG_FILE_PATH
    printf "$(timestamp) [4-1]: Checking $TF_PLAN exists..." | tee -a $LOG_FILE_PATH

    check_file_exists "${PWD}/$TF_PLAN" "2"

    printf "$(timestamp) [4-2]: Deploying the bootstrap infrastructure..." | tee -a $LOG_FILE_PATH
    set -e # Exit on error
    terraform apply $TF_PLAN -auto-approve 2>&1 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1
;;

esac

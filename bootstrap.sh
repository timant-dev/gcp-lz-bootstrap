#!/bin/bash

set -eo pipefail

# SHELL COMMAND USAGE:
# Currently accepts two arguments; one for config file and numeric value for focused testing. Second arg will be removed following successful tests.
if [ $# -lt 2 ]; then
  printf "Usage : $0 arg1 arg2\n"
  printf "Example: ./bootstrap.sh client.conf 1"
  printf "Options: 
    arg1 = config file 
    arg2 = 1..7.
        1 (to 5) = Creates var file, workspace, runs terraform plan and apply, updates backend and generates ssh keys.
        6 = Clone the private GitHub repo and push into cloud source repo.
        7 = Run terraform to add cloud build CI job triggers for next LZ phase.
        \n"
  exit
fi

# CONSTANTS FOR EXECUTION STATUSES
STEP_DONE="DONE!\n"
STEP_SUCCESS="SUCCESS!\n"
STEP_FAIL="FAIL!\n"

# CHECKPOINTS ARE EMBEDDED IN STEPS AND INTENDED TO PROMPT USER TO PERFORM CHECKS.
# YES = ENABLE; NO = DISABLE
CHECKPOINT_ENABLED="YES"

# REUSABLE FUNCTION TO PREFIX STDOUT MESSAGES/COMMENTS WITH TIMESTAMP
function timestamp()
{
    date +"%Y-%m-%d %T"
}

# REUSABLE FUNCTION TO PAUSE SCRIPT EXECUTION FOR USER CONFIRMATION - DEPENDS ON CHECKPOINT_ENABLED variable 
function pause()
{
if [[ $CHECKPOINT_ENABLED == "YES" ]]; then
    printf "\n"
    while true; do
        read -p "$*" USER_INPUT
        case $USER_INPUT in 
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please enter yes or no.";;
        esac
    done
    printf "\n"
fi
}

# >>>> STEP 0 - Source conf file and create log file if missing <<<<<<<
printf "\n>>>>>>>>>> RUNNING: STEP #0.\n\n"
printf "$(timestamp) [0-0]: Sourcing environment variables from .conf file..." 
source $1 # Source config file
printf $STEP_DONE; sleep 2

printf "$(timestamp) [0-1]: Checking client log file exist ..."
if [[ -f $LOG_FILE_PATH ]]; then
    #printf "YES! - ${LOG_FILE_PATH}\n"
    printf "YES!\n"
else
    printf "NO!\n"
    printf "$(timestamp) [0-2]: Creating log file..."
    touch $LOG_FILE_PATH
    printf "${LOG_FILE_PATH} created successfully!\n"
fi; sleep 2

# REUSABLE FUNCTION TO CHECK A FILE EXISTS AND REPORTS AN ERROR IF ONE IS NOT FOUND
function check_file_exists()
{
    local file="$1"
    local number="$2"
    
    if [ -f $file ]; then
        printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH
    else
        printf $STEP_FAIL | tee -a $LOG_FILE_PATH
        printf "$(timestamp) [ERROR]: $file file is missing. Execute step #$number.\n" | tee -a $LOG_FILE_PATH
        exit 1
    fi
}

# START OF SWITCH CASE STATEMENTS - INTENDED FOR FOCUSED UNIT TESTING.
case $2 in
1) 
# >>>> STEP 1 - Initialize variables and generate terraform.tfvars <<<<<<<
    printf "\n>>>>>>>>>> RUNNING: STEP #1.\n\n" | tee -a $LOG_FILE_PATH
    printf "$(timestamp) [1-01]: Initialising terraform variables..." | tee -a $LOG_FILE_PATH
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
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [1-02]: Generating terraform.tfvars file..." | tee -a $LOG_FILE_PATH

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

    printf "$(timestamp) [1-03]: Instruction - Review the terraform.tfvar contents before proceeding to the next step:\n\n"
    cat ${PWD}/terraform.tfvars
    printf "\n"; sleep 1

    pause "[CHECKPOINT #1]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!!

# >>>> STEP 2 - Initialize terraform, create workspace and plan <<<<<<<
    printf ">>>>>>>>>> RUNNING: STEP #2. \n\n" | tee -a $LOG_FILE_PATH

    #check_file_exists "${PWD}/terraform.tfvars" "1"

    printf "$(timestamp) [2-1]: Initializing terraform..." | tee -a $LOG_FILE_PATH
    terraform init 2>&1 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [2-2]: Create new terraform workspace 'bootstrap'..." | tee -a $LOG_FILE_PATH
    
    set +e # Skip warning message about existing workspace

    terraform workspace new bootstrap 1>&2 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    set -e # Enable error reporting

    printf "$(timestamp) [2-3]: Format terraform files and validate..." | tee -a $LOG_FILE_PATH
    terraform fmt 2>&1 >> $LOG_FILE_PATH
    terraform validate 1>&2 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [2-4]: Generate terraform plan..." | tee -a $LOG_FILE_PATH
    if [ -f "${PWD}/$TF_PLAN" ]
    then
        printf "Found existing plan! Replacing..." | tee -a $LOG_FILE_PATH
        rm $TF_PLAN
    fi
    
    terraform plan -out=$TF_PLAN 2>&1 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [2-5]: Instruction - Review the generated plan before deploying. Run 'terraform show bootstrap.tfplan'.\n"; sleep 2

    #pause "[CHECKPOINT #2]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!!

# >>>> STEP 3 - Deploy bootstrap resources <<<<<<<
    printf "\n>>>>>>>>>> RUNNING: STEP #3.\n\n" | tee -a $LOG_FILE_PATH

    printf "$(timestamp) [3-1]: Deploying the bootstrap infrastructure..." | tee -a $LOG_FILE_PATH
    terraform apply -auto-approve $TF_PLAN  2>&1 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [3-2]: Instruction - Review terraform output by running 'terraform show output'.\n"; sleep 2

    #pause "[CHECKPOINT #3]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!!

# >>>> STEP 4 - Update and migrate terraform state to GCS backend <<<<
    printf "\n>>>>>>>>>> RUNNING: STEP #4.\n\n" | tee -a $LOG_FILE_PATH
    
    #export BUCKET_NAME=$(terraform output -raw tf-state-bucket-name)
    export BUCKET_NAME="appdev-320214-terraform"
    printf "$(timestamp) [4-1]: Updating terraform gcs backend conf with state bucket name..." | tee -a $LOG_FILE_PATH
    
    # Check variable is populated with bucket name from terraform output
    if [ -z "${BUCKET_NAME}" ]
    then
        printf "$(timestamp) [ERROR]: GCS bucket name not populated.\n" | tee -a $LOG_FILE_PATH
        exit 1
    fi

    cp $WORKDIR/backend.tf.example $WORKDIR/backend.tf.stage
    sed -i "s/BUCKET_NAME_PLACEHOLDER/${BUCKET_NAME}/" $WORKDIR/backend.tf.stage
    mv $WORKDIR/backend.tf.stage $WORKDIR/backend.tf

    if [ -f "$WORKDIR/backend.tf" ]; then
        printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1
    else
        printf "$(timestamp) [ERROR]: Backend.tf file not generated successfully.\n" | tee -a $LOG_FILE_PATH
        exit 1
    fi

    printf "$(timestamp) [4-2]: Instruction - Review backend config file below before proceeding to the next step:\n\n"
    cat ${PWD}/backend.tf
    printf "\n"; sleep 1

    pause "[CHECKPOINT #4]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!!

    printf "$(timestamp) [4-3]: Migrating terraform state from local to GCS remote..."
    terraform init -migrate-state -force-copy 1>&2 | tee -a $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

# >>>> STEP 5 - Generate github keys and configure git global <<<<
    printf "\n>>>>>>>>>> RUNNING: STEP #5.\n\n" | tee -a $LOG_FILE_PATH

    printf "$(timestamp) [5-1]: Generate keys to connect to private Github repo..." | tee -a $LOG_FILE_PATH
    ssh-keygen -t rsa -b 4096 -N "" -q -C "${GITHUB_BOT_USER}" -f ~/.ssh/id_github > /dev/null # command output is suppressed
    ssh-keyscan -t rsa github.com 2>&1 | tee ~/.ssh/known_hosts > /dev/null
    cat ssh_config_template > ~/.ssh/config # Check file exists!!!
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [5-2]: Configure the cloudshell git session (email, name and credential)..." | tee -a $LOG_FILE_PATH
    git config --global user.email "${GITHUB_BOT_USER}" && git config --global user.name "${GITHUB_BOT_NAME}" 2>&1 >> $LOG_FILE_PATH
    git config --global credential.https://source.developers.google.com.helper gcloud.sh 2>&1 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [5-3]: InstructionS -
    Add the public SSH key as a deploy key on the Github repo.
    Copy the generated public key and add it as a deploy key on the private Github repo.
    See instructions here : $DEPLOY_KEY_DOC_LINK
    Once you've added the deploy key to the Github repo, run step #6.\n\n"
    
    pause "[CHECKPOINT #5]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!!
;;

6) # Retained case statement for focused testing and will be removed following successful runs.
# >>>> STEP 6 - Clone the private GitHub repo and push into cloud source repo <<<<
    printf "\n>>>>>>>>>> RUNNING: STEP #6.\n\n" | tee -a $LOG_FILE_PATH

    printf "$(timestamp) [6-1]: Exporting env variables..." | tee -a $LOG_FILE_PATH 
    export GITHUB_SSH_URL=$(echo ${GITHUB_URL} | sed 's/https:\/\/github.com\//git\@github.com:/;s/$/.git/')
    export SEED_PROJ=$(terraform output -raw seed_project_id)
    export GITHUB_REPO_NAME=$(basename ${GITHUB_URL})
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH

    printf "$(timestamp) [6-2]: Cloning private GitHub repo..." | tee -a $LOG_FILE_PATH 
    cd ${HOME} && git clone ${GITHUB_SSH_URL} 2>&1 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 1

    printf "$(timestamp) [6-3]: Add remote origin, checkout and push into cloud source repo..." | tee -a $LOG_FILE_PATH  
    cd ${HOME}/${GITHUB_REPO_NAME}
    git remote add google https://source.developers.google.com/p/${SEED_PROJ}/r/${GITHUB_REPO_NAME} 2>&1 >> $LOG_FILE_PATH
    git push --all google 2>&1 >> $LOG_FILE_PATH
    git checkout --track remotes/origin/develop && git push google 2>&1 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 2
;;

7) # Retained case statement for focused testing and will be removed following successful runs.
# >>>> STEP 7 - Run terraform to add cloud build CI job triggers for next LZ phase <<<<
    printf "\n>>>>>>>>>> RUNNING: STEP #7.\n\n" | tee -a $LOG_FILE_PATH
    printf "$(timestamp) [7-1]: invoke terraform to provision the LZ cloud build job triggers..." | tee -a $LOG_FILE_PATH  
    cd ${WORKDIR} && terraform apply -auto-approve -var="enable_cb_triggers=true" 2>&1 >> $LOG_FILE_PATH
    printf $STEP_SUCCESS | tee -a $LOG_FILE_PATH; sleep 2

    printf "\n\n Bootstrap phase for $CLIENT_SHORT_NAME landing zone completed successfull!!!!\n" | tee -a $LOG_FILE_PATH
;;

esac

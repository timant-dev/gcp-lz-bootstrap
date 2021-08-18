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

# CONSTANTS FOR EXECUTION STATUSEScd 
STEP_DONE="DONE!\n"
STEP_SUCCESS="SUCCESS!\n"
STEP_FAIL="FAIL!\n"

# REUSABLE FUNCTION TO PREFIX STDOUT MESSAGES/COMMENTS WITH TIMESTAMP
function timestamp()
{
    date +"%Y-%m-%d %T"
}

# >>>> STEP 0 - Source conf file and create log file if missing <<<<<<<
printf "\n>>>>>>>>>> RUNNING: STEP #0.\n\n"
printf "$(timestamp) [0-0]: Sourcing environment variables from .conf file..." 
source $1 # Source config file
printf $STEP_DONE; sleep 2

# CHECKPOINTS ARE EMBEDDED IN STEPS AND INTENDED TO PROMPT USER TO PERFORM CHECKS; YES = ENABLE; NO = DISABLE
while true; do
    read -p "$(timestamp) [0-1]: Enable checkpoints? [Y/N]: " CHECKPOINT
    case $CHECKPOINT in 
        [Yy]*) CHECKPOINT_ENABLED="Yes"; printf "$(timestamp) [0-2]: Checkpoints ENABLED!\n"; break;;
        *) CHECKPOINT_ENABLED="No"; printf "$(timestamp) [0-2]: Checkpoints DISABLED!\n"; break;;
    esac
done

printf "$(timestamp) [0-3]: Checking client log file exist ..."
# Check if log directory exists, if not create it
if [[ ! -d $LOG_DIR ]]; then
    mkdir $LOG_DIR
fi

if [[ -f $LOG_FILE_PATH ]]; then
    printf "YES!\n"
else
    printf "NO!\n"
    printf "$(timestamp) [0-4]: Creating log file..."
    touch $LOG_FILE_PATH
    printf "${LOG_FILE_PATH} created successfully!\n"
fi; sleep 2

# REDIRECT STDOUT AND STDERR TO LOG FILE. SELECTIVELY DISPLAY STEPS BY REDIRECTING TO >&3
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>$LOG_FILE_PATH 2>&1

# WRAPPER TO ENABLE SELECTED OUTPUTS TO BOTH CONSOLE AND LOG FILE
function echothis ()
{
    printf "$1" | tee -a $LOG_FILE_PATH >&3
}

# REUSABLE FUNCTION TO PAUSE SCRIPT EXECUTION FOR USER CONFIRMATION - DEPENDS ON CHECKPOINT_ENABLED variable 
function pause()
{
if [[ $CHECKPOINT_ENABLED == "Yes" ]]; then
    echothis "\n"
    while true; do
        #read -p "$*" USER_INPUT
        echothis "$1"
        read USER_INPUT
        case $USER_INPUT in 
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echothis "Please enter yes or no.";;
        esac
    done
    echothis "\n"
fi
}

# START OF SWITCH CASE STATEMENTS - INTENDED FOR FOCUSED UNIT TESTING.
case $2 in
1) 
# >>>> STEP 1 - Initialize variables and generate terraform.tfvars <<<<<<<
    echothis "\n>>>>>>>>>> RUNNING: STEP #1.\n\n"
    echothis "$(timestamp) [1-1]: Initialising terraform variables..."
    if [[ (-z "${CLIENT_SHORT_NAME}") || 
        (-z "${ORG_ID}") || 
        (-z "${ORG_DOMAIN}") ||       
        (-z "${BILL_ID}") || 
        (-z "${GCS_REGION}") || 
        (-z "${DEFAULT_REGION}") ||
        (-z "${WORKLOAD_NETWORK_REGIONS}") 
    ]]
    then
    echothis $STEP_FAIL
    echothis "$(timestamp) [ERROR]: One or more variables not populated. Check config file.\n"
    exit 1
    fi
    echothis $STEP_SUCCESS; sleep 1

    echothis "$(timestamp) [1-2]: Generating terraform.tfvars file..."

    cat > ${PWD}/terraform.tfvars <<EOL
    client_short_name = "${CLIENT_SHORT_NAME}"
    org_id = "${ORG_ID}"
    org_domain = "${ORG_DOMAIN}"
    billing_account_id = "${BILL_ID}"
    gcs_region = "${GCS_REGION}"
    default_region = "${DEFAULT_REGION}"
    workload_env_subnet_regions = "${WORKLOAD_NETWORK_REGIONS}"
EOL

    echothis $STEP_SUCCESS; sleep 1

    echothis "$(timestamp) [1-3]: Instruction - Review the terraform.tfvar contents before proceeding to the next step:\n\n"
    cat ${PWD}/terraform.tfvars | tee -a $LOG_FILE_PATH >&3
    echothis "\n"; sleep 1

    pause "[CHECKPOINT #1]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!!

# >>>> STEP 2 - Initialize terraform, create workspace and plan <<<<<<<
    echothis ">>>>>>>>>> RUNNING: STEP #2. \n\n"

    echothis "$(timestamp) [2-1]: Initializing terraform..."
    terraform init
    echothis $STEP_SUCCESS; sleep 1

    echothis "$(timestamp) [2-2]: Create new terraform workspace 'bootstrap'..."
    
    set +e # Skip warning message about existing workspace

    terraform workspace new bootstrap
    echothis $STEP_SUCCESS; sleep 1

    set -e # Enable error reporting

    echothis "$(timestamp) [2-3]: Format terraform files and validate..."
    terraform fmt && terraform validate
    echothis $STEP_SUCCESS; sleep 1

    echothis "$(timestamp) [2-4]: Generate terraform plan..."
    if [ -f "${PWD}/$TF_PLAN" ]
    then
        echothis "Found existing plan! Replacing..."
        rm $TF_PLAN
    fi
    
    terraform plan -out=$TF_PLAN
    echothis $STEP_SUCCESS; sleep 1

    echothis "$(timestamp) [2-5]: Instruction - Review the generated plan before deploying. Run 'terraform show bootstrap.tfplan'.\n"; sleep 2

    pause "[CHECKPOINT #2]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!!

# >>>> STEP 3 - Deploy bootstrap resources <<<<<<<
    echothis "\n>>>>>>>>>> RUNNING: STEP #3.\n\n"
    echothis "$(timestamp) [3-1]: Deploying the bootstrap infrastructure..."
    
    terraform apply -auto-approve $TF_PLAN
    
    echothis $STEP_SUCCESS; sleep 1
    echothis "$(timestamp) [3-2]: Instruction - Review terraform output by running 'terraform show output'.\n"; sleep 2
    pause "[CHECKPOINT #3]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!!

# >>>> STEP 4 - Update and migrate terraform state to GCS backend <<<<
    echothis "\n>>>>>>>>>> RUNNING: STEP #4.\n\n"    
    echothis "$(timestamp) [4-1]: Updating terraform gcs backend conf with state bucket name..."

    export BUCKET_NAME=$(terraform output -raw tf-state-bucket-name)
    #export BUCKET_NAME="appdev-320214-terraform"
    
    if [ -z "${BUCKET_NAME}" ] # Check variable is populated with bucket name from terraform output
    then
        echothis "$(timestamp) [ERROR]: GCS bucket name not populated.\n"
        exit 1
    fi

    # Preserve example file for templated use by copying it before replacing the embedded placeholder
    cp $WORKDIR/backend.tf.example $WORKDIR/backend.tf.stage
    sed -i "s/BUCKET_NAME_PLACEHOLDER/${BUCKET_NAME}/" $WORKDIR/backend.tf.stage
    mv $WORKDIR/backend.tf.stage $WORKDIR/backend.tf

    if [ -f "$WORKDIR/backend.tf" ]; then
        echothis $STEP_SUCCESS; sleep 1
    else
        echothis "$(timestamp) [ERROR]: Backend.tf file not generated successfully.\n"
        exit 1
    fi

    echothis "$(timestamp) [4-2]: Instruction - Review backend config file below before proceeding to the next step:\n\n"
    
    cat ${PWD}/backend.tf | tee -a $LOG_FILE_PATH >&3
    
    echothis "\n"; sleep 1
    pause "[CHECKPOINT #4]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!!

    echothis "$(timestamp) [4-3]: Migrating terraform state from local to GCS remote..."
    terraform init -migrate-state -force-copy | tee -a $LOG_FILE_PATH >&3
    echothis $STEP_SUCCESS; sleep 1

# >>>> STEP 5 - Generate github keys and configure git global <<<<
    echothis "\n>>>>>>>>>> RUNNING: STEP #5.\n\n"

    echothis "$(timestamp) [5-1]: Generate keys to connect to private Github repo..."
    ssh-keygen -t rsa -b 4096 -N "" -q -C "${GITHUB_BOT_USER}" -f ~/.ssh/id_github 2>&1> /dev/null # suppress output
    ssh-keyscan -t rsa github.com 2>&1 | tee ~/.ssh/known_hosts > /dev/null 2&>1 # suppress output
    cat ssh_config_template > ~/.ssh/config
    echothis $STEP_SUCCESS; sleep 1

    echothis "$(timestamp) [5-2]: Configure the cloudshell git session (email, name and credential)..."
    git config --global user.email "${GITHUB_BOT_USER}" && git config --global user.name "${GITHUB_BOT_NAME}"
    git config --global credential.https://source.developers.google.com.helper gcloud.sh
    echothis $STEP_SUCCESS; sleep 1

    echothis "$(timestamp) [5-3]: Instructions -
    Add the public SSH key as a deploy key on the Github repo.
    Copy the generated public key and add it as a deploy key on the private Github repo.
    See instructions here : $DEPLOY_KEY_DOC_LINK
    Once you've added the deploy key to the Github repo, run step #6.\n\n"
    
    pause "[CHECKPOINT #5]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!!
;;

6) # Retained case statement for focused testing and will be removed following successful runs.
# >>>> STEP 6 - Clone the private GitHub repo and push into cloud source repo <<<<
    echothis "\n>>>>>>>>>> RUNNING: STEP #6.\n\n"

    echothis "$(timestamp) [6-1]: Exporting env variables..." 
    export GITHUB_SSH_URL=$(echo ${GITHUB_URL} | sed 's/https:\/\/github.com\//git\@github.com:/;s/$/.git/')
    export SEED_PROJ=$(terraform output -raw seed_project_id)
    export GITHUB_REPO_NAME=$(basename ${GITHUB_URL})
    echothis $STEP_SUCCESS

    echothis "$(timestamp) [6-2]: Cloning private GitHub repo..." 
    cd ${HOME} && git clone ${GITHUB_SSH_URL}
    echothis $STEP_SUCCESS; sleep 1

    echothis "$(timestamp) [6-3]: Add remote origin, checkout and push into cloud source repo..."  
    cd ${HOME}/${GITHUB_REPO_NAME}
    git remote add google https://source.developers.google.com/p/${SEED_PROJ}/r/${GITHUB_REPO_NAME}
    git push --all google
    git checkout --track remotes/origin/develop && git push google
    echothis $STEP_SUCCESS; sleep 2
;;

7) # Retained case statement for focused testing and will be removed following successful runs.
# >>>> STEP 7 - Run terraform to add cloud build CI job triggers for next LZ phase <<<<
    echothis "\n>>>>>>>>>> RUNNING: STEP #7.\n\n"
    echothis "$(timestamp) [7-1]: invoke terraform to provision the LZ cloud build job triggers..."  
    cd ${WORKDIR} && terraform apply -auto-approve -var="enable_cb_triggers=true"
    echothis $STEP_SUCCESS; sleep 2

    echothis "\n\n Bootstrap phase for $CLIENT_SHORT_NAME landing zone completed successfull!!!!\n"
;;

esac

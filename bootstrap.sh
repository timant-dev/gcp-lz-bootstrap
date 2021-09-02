#!/bin/bash
clear

set -o pipefail

# VARIABLES #########################################################

WORKDIR=${PWD} # Current directory at runtime
PARENTDIR=$WORKDIR/../..
TF_DIR=$WORKDIR #$WORKDIR/terraform
TF_PLAN="bootstrap.tfplan" # terraform plan
TF_WORKSPACE="bootstrap"
DEPLOY_KEY_DOC_LINK="https://docs.github.com/en/developers/overview/managing-deploy-keys#deploy-keys" # Github link to deploy keys
STEP_DONE="DONE!\n"
STEP_SUCCESS="SUCCESS!\n"
STEP_FAIL="FAIL!\n"

# FUNCTIONS #########################################################

function usage () {
    echo "Usage:"
    echo "  $0 [FILE.CONF] [STEP] ; Run bootstrap specifying client config file (.conf) and step option*"
    echo ""
    echo "Examples:"
    echo "  $0 bjss.conf all"   # Run all steps with checkpoint enabled.
    echo "  $0 bjss.conf 3"     # Re-run step #3
    echo ""
    echo " *STEP options: "
    echo "      all) = run all bootstrap steps with user checkpoints enabled for steps 1-6."
    echo "      1) = Generate terraform.tfvars file."
    echo "      2) = Create terraform workspace and plan."
    echo "      3) = Apply terraform plan. Avg run time > 30m"
    echo "      4) = Migrate terraform backend."
    echo "      5) = Generate ssh keys and configure git."
    echo "      6) = Clone private git and push to cloud source repo."
    echo "      7) = Provision cloud build job triggers."
    echo ""
}

if [[ $# -lt 2 ]]; then
    printf "[ERROR]: Command argument(s) expected.\n\n"
    usage
    exit 1
else 
    export CONFIG=$1 # Config file argument
    export STEP=$2   # Numbered step argument
fi

function timestamp () { # Timestamp to prefix messages
    date +"%Y-%m-%d %T"
}

function step0_prep_tasks () {
    LOG_DIR=$WORKDIR/logs # Log file path

    printf "\n>>>>>>>>>> RUNNING: STEP #0.\n\n"
    printf "$(timestamp) [0-1]: Checking bootstrap pre-requisites ...\n"
    
    # Source file: check if source file exists and throw error if it doesn't. Include actual file name passed in print statement
    if [[ ! "${CONFIG: -5}" == ".conf" ]]; then
        printf "$(timestamp) [ERROR]: Config file missing. Please provide a file with a .conf extension.\n"
        exit 1
    else
        source $CONFIG # Read in source config file
    fi    

     # Dependent on source file
    LOG_FILE=$CLIENT_SHORT_NAME-"`date '+%y-%m-%d'`.log" # Log file name
    LOG_FILE_PATH=$LOG_DIR/$LOG_FILE # Log file path

    # Log file directory check.
    if [[ ! -d $LOG_DIR ]]; then
        mkdir $LOG_DIR
    fi

    # Log file: check daily log file exists and create one if none exists. Previous log files are retained.
    if [[ ! -f $LOG_FILE_PATH ]]; then
        touch $LOG_FILE_PATH
    fi

    case $STEP in
        all|3) export CHECKPOINT_ENABLED="Yes";; 
        *) export CHECKPOINT_ENABLED="No";;
    esac

    echo "======================="
    echo " Bootstrap parameters: "
    echo "======================="
    echo "  - Client name           = $CLIENT_SHORT_NAME"
    echo "  - Config file           = $CONFIG"
    echo "  - Execution step        = $STEP"
    echo "  - Checkpoints enabled?  = $CHECKPOINT_ENABLED"
    echo "  - Log file path         = $LOG_FILE_PATH"
    echo ""
}

# Run preparatory tasks
step0_prep_tasks

# Redirect STDOUT and STDERR to log file and screen.
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>$LOG_FILE_PATH 2>&1

function printout () { 
    # Function wrapper to override setting to redirect to stdout and log file
    printf "$1" | tee -a $LOG_FILE_PATH >&3
}

function pause_script () {
    # Function to pause script execution and wait for user response.
    if [[ $CHECKPOINT_ENABLED == "Yes" ]]; then
        printout "\n"
        while true; do
            printout "$1"
            read USER_INPUT
            case $USER_INPUT in 
                [Yy]* ) break;; # Continue script run
                [Nn]* ) exit;; # Terminate script
                * ) printout "Please enter (Y)es or (N)o.\n";;
            esac
        done
        printout "\n"
    fi
}

function check_exit_code () {
    # Function to check the exit status code of last run command
    if [[ $1 -eq 0 ]]; then
        printout $STEP_SUCCESS 
    else
        printout $STEP_FAIL 
        if [[ $2 == "" ]]; then
            printout "$(timestamp) [ERROR]: An error has occurred. Please refer to the log file for more details.\n\n"
        else
            printout "$2" # Prints the custom message passed as second argument
        fi
        tail -n 15 $LOG_FILE_PATH | egrep '(Error:|ERROR:|Error |fatal:)' -C 5 >&3 # Output excerpt of error from log file.
        exit 1
    fi
}

function step1_generate_terraform_tfvars () {
    # Function to generate terraform.tfvars file from mandatory variables set locally and provided in conf file.
    
    # Global variables
    ORG_ID=$(gcloud organizations list --format='value(ID)') 
    ORG_DOMAIN=$(gcloud organizations list --format='value(displayName)') 
    BILL_ID=$(gcloud alpha billing accounts list --format='value(ACCOUNT_ID)' --filter='OPEN=True')
    
    printout "\n>>>>>>>>>> RUNNING: STEP #1.\n\n"
    printout "$(timestamp) [1-1]: Initialising terraform variables..."
    if [[ (-z "${ORG_ID}") || 
        (-z "${ORG_DOMAIN}") ||       
        (-z "${BILL_ID}") || 
        (-z "${CLIENT_SHORT_NAME}") ||          # From config file
        (-z "${GCS_REGION}") ||                 # From config file
        (-z "${DEFAULT_REGION}") ||             # From config file
        (-z "${WORKLOAD_NETWORK_REGIONS}") ]]   # From config file
    then
        printout $STEP_FAIL
        printout "$(timestamp) [ERROR]: One or more variables not populated. Check config file.\n"
        exit 1        
    fi
    #printout $STEP_SUCCESS; sleep 1
    check_exit_code $?

    printout "$(timestamp) [1-2]: Generating terraform.tfvars file..."
    cat > ${PWD}/terraform.tfvars <<EOL
    client_short_name           = "${CLIENT_SHORT_NAME}"
    org_id                      = "${ORG_ID}"
    org_domain                  = "${ORG_DOMAIN}"
    billing_account_id          = "${BILL_ID}"
    gcs_region                  = "${GCS_REGION}"
    default_region              = "${DEFAULT_REGION}"
    workload_env_subnet_regions = "${WORKLOAD_NETWORK_REGIONS}"
EOL
    #printout $STEP_SUCCESS; sleep 1
    check_exit_code $?

    printout "$(timestamp) [1-3]: Instruction - Review the terraform.tfvar contents before proceeding to the next step:\n\n"
    cat ${PWD}/terraform.tfvars | tee -a $LOG_FILE_PATH >&3
    printout "\n"; sleep 1

    pause_script "[CHECKPOINT #1]: Do you want to continue? [Y/N]: "
}

function step2_create_terraform_workspace_and_plan () {
    printout ">>>>>>>>>> RUNNING: STEP #2. \n\n"
    printout "$(timestamp) [2-1]: Initializing terraform..."

    if [[ -f $TF_DIR/backend.tf ]]; then
        printout "Backend.tf file exists!!\n"; sleep 2
    fi

    terraform init | tee -a $LOG_FILE_PATH >&3
    check_exit_code $?
    
    printout "$(timestamp) [2-2]: Create new terraform workspace 'bootstrap'..."
    terraform workspace list | grep $TF_WORKSPACE # Create workspace if it doesn't exist
    if [[ $? == 1 ]]; then
        terraform workspace new $TF_WORKSPACE | tee -a $LOG_FILE_PATH >&3
        check_exit_code $?
    else
        printout $STEP_SUCCESS; sleep 1
    fi

    printout "$(timestamp) [2-3]: Format terraform files and validate..."
    terraform fmt
    terraform validate | tee -a $LOG_FILE_PATH >&3
    check_exit_code $?

    printout "$(timestamp) [2-4]: Generate terraform plan..."
    # Additional check for terraform.tfvars file
    if [[ ! -f "$WORKDIR/terraform.tfvars" ]]; then 
        check_exit_code $? "$(timestamp) [ERROR]: Missing file 'terraform.tfvars'. Re-run step 1 to create file.\n"
    fi

    if [[ -f "$WORKDIR/$TF_PLAN" ]]; then
        printout "Found existing plan! Overwriting..."
        rm $TF_PLAN
        check_exit_code $?
    fi

    terraform plan -out=$TF_PLAN | tee -a $LOG_FILE_PATH >&3
    check_exit_code $?

    printout "\n$(timestamp) [2-5]: Instruction - Review the terraform plan above before deploying.\n\n"; sleep 2

    pause_script "[CHECKPOINT #2]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!
}

function step3_apply_terraform_plan () {
    printout "\n>>>>>>>>>> RUNNING: STEP #3.\n\n"
    printout "$(timestamp) [3-1]: Deploying the bootstrap infrastructure, please wait ...\n\n"
    
    terraform apply -auto-approve $TF_PLAN | tee -a $LOG_FILE_PATH >&3
    check_exit_code $?

    # Run terraform output
    printout "\n$(timestamp) [3-2]: Instruction - Review terraform output above before running the next step.\n"
    
    pause_script "[CHECKPOINT #3]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!
}

function step4_migrate_terraform_backend () {
    printout "\n>>>>>>>>>> RUNNING: STEP #4.\n\n"    
    printout "$(timestamp) [4-1]: Updating terraform gcs backend conf with state bucket name..."

    export BUCKET_NAME=$(terraform output -raw tf-state-bucket-name)
    
    if [[ (-z "${BUCKET_NAME}") || ($BUCKET_NAME == "|") ]]; then 
        printout $STEP_FAIL
        printout "$(timestamp) [ERROR]: GCS bucket name not populated.\n"
        exit 1
    fi

    # Preserve example file for templated use by copying it before replacing the embedded placeholder
    cp $WORKDIR/backend.tf.example $WORKDIR/backend.tf.stage
    sed -i "s/BUCKET_NAME_PLACEHOLDER/${BUCKET_NAME}/" $WORKDIR/backend.tf.stage
    mv $WORKDIR/backend.tf.stage $WORKDIR/backend.tf

    if [ -f "$WORKDIR/backend.tf" ]; then # Confirm backend file exists
        printout $STEP_SUCCESS; sleep 1
    else
        printout "$(timestamp) [ERROR]: Backend.tf file not generated successfully.\n"
        exit 1
    fi

    printout "$(timestamp) [4-2]: Instruction - Review backend config file below before proceeding to the next step:\n\n"

    cat ${PWD}/backend.tf | tee -a $LOG_FILE_PATH >&3

    printout "\n"
    pause_script "[CHECKPOINT #4.1]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!

    printout "$(timestamp) [4-3]: Migrating terraform state from local to GCS remote..."
    terraform init -migrate-state -force-copy | tee -a $LOG_FILE_PATH >&3
    check_exit_code $?

    pause_script "[CHECKPOINT #4.2]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!
}


function step5_generate_sshkeys_and_configure_git () {
    printout "\n>>>>>>>>>> RUNNING: STEP #5.\n\n"
    printout "$(timestamp) [5-1]: Generate keys to connect to private Github repo..."

    if [[ (-f "$HOME/.ssh/id_github") || (-f "$HOME/.ssh/known_hosts") ]]; then
        printout $STEP_FAIL
        printout "$(timestamp) [ERROR]: SSH keys already exists! Refer to directory $HOME/.ssh. \n\n"; sleep 1
        exit 1
    fi

    # Generate keys if they don't exist
    ssh-keygen -t rsa -b 4096 -N "" -q -C "${GITHUB_BOT_USER}" -f ~/.ssh/id_github > /dev/null # suppress output
    ssh-keyscan -t rsa github.com | tee ~/.ssh/known_hosts > /dev/null # suppress output
    check_exit_code $?

    cat ssh_config_template > ~/.ssh/config

    printout "$(timestamp) [5-2]: Configure the cloudshell git session (email, name and credential)..."
    git config --global user.email "${GITHUB_BOT_USER}"
    git config --global user.name "${GITHUB_BOT_NAME}"
    git config --global credential.https://source.developers.google.com.helper gcloud.sh
    check_exit_code $?

    printout "$(timestamp) [5-3]: \nInstructions -
    - Add the public SSH key as a deploy key on the Github repo.
    - Copy the generated public key and add it as a deploy key on the private Github repo.
    - See instructions here : $DEPLOY_KEY_DOC_LINK
    - Once you've added the deploy key to the Github repo, run step #6.\n\n"

    pause_script "[CHECKPOINT #5]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!
}

function step6_clone_privategit_and_push_into_cloudrepo () {
    printout "\n>>>>>>>>>> RUNNING: STEP #6.\n\n"
    printout "$(timestamp) [6-1]: Exporting env variables..." 

    export GITHUB_SSH_URL=$(echo ${GITHUB_URL} | sed 's/https:\/\/github.com\//git\@github.com:/;s/$/.git/')
    export SEED_PROJ=$(terraform output -raw seed_project_id)
    export GITHUB_REPO_NAME=$(basename ${GITHUB_URL})
    check_exit_code $?

    printout "$(timestamp) [6-2]: Cloning private GitHub repo...\n" 
    cd ${HOME}

    # Remove repo directory if it already exists in order to ensure clone is latest repo version
    if [[ -d ${HOME}/${GITHUB_REPO_NAME} ]]
    then
      printout "$(timestamp) [6-2]: Copy of cloned repo already exists locally. Will delete and clone latest version..."
      rm -rf ${GITHUB_REPO_NAME}
    fi
    git clone ${GITHUB_SSH_URL}; check_exit_code $?

    printout "$(timestamp) [6-3]: Add remote origin, checkout and push into cloud source repo..."  
    cd ${HOME}/${GITHUB_REPO_NAME}

    # Get name of Cloud Source Repo from Terraform output as it may differ from cloned repo name
    export TF_CSR_REPO_NAME=$(terraform output -raw tf_csr_repo_name)
    printout "$(timestamp) [6-3]: Creating git remote for Cloud Source Repo name = ${TF_CSR_REPO_NAME}"
    git remote add google https://source.developers.google.com/p/${SEED_PROJ}/r/${TF_CSR_REPO_NAME} | tee -a $LOG_FILE_PATH >&3
    git push --all google | tee -a $LOG_FILE_PATH >&3
    git checkout --track remotes/origin/develop && git push google | tee -a $LOG_FILE_PATH >&3
    check_exit_code $?
    
    pause_script "[CHECKPOINT #1]: Do you want to continue? [Y/N]: " # CHECKPOINT!!!
}

function step7_provision_cloudbuild_jobtriggers () {
    printout "\n>>>>>>>>>> RUNNING: STEP #7.\n\n"
    printout "$(timestamp) [7-1]: invoke terraform to provision the LZ cloud build job triggers..."  
    cd ${WORKDIR}
    terraform apply -auto-approve -var="enable_cb_triggers=true" | tee -a $LOG_FILE_PATH >&3
    check_exit_code $?

    printout "\n\n the Bootstrap phase for $CLIENT_SHORT_NAME landing zone completed successfully!!!!\n"
}

case $STEP in 
all) # Run all steps with checkpoints auto-enabled
    step1_generate_terraform_tfvars
    step2_create_terraform_workspace_and_plan
    step3_apply_terraform_plan
    step4_migrate_terraform_backend
    step5_generate_sshkeys_and_configure_git
    step6_clone_privategit_and_push_into_cloudrepo
    step7_provision_cloudbuild_jobtriggers;;
1)  
    step0_prep_tasks
    step1_generate_terraform_tfvars;;
2)  
    step2_create_terraform_workspace_and_plan;;
3)  
    step3_apply_terraform_plan;;
4)  
    step4_migrate_terraform_backend;;
5)  
    step5_generate_sshkeys_and_configure_git;;
6)  
    step6_clone_privategit_and_push_into_cloudrepo;;
7)  
    step7_provision_cloudbuild_jobtriggers;;

esac

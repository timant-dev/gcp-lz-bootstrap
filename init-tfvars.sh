#!/bin/bash
sed -i.bak "s/XXXXXX/$(gcloud organizations list --format='value(ID)')/;s/ZZZZZZ/$(gcloud alpha billing accounts list --format='value(ACCOUNT_ID)' --filter='OPEN=True')/" ${PWD}/terraform.tfvars.example
mv ${PWD}/terraform.tfvars.example ${PWD}/terraform.tfvars
#!/bin/bash
export BUCKET_NAME=$(terraform output -raw tf-state-bucket-name)
sed -i.bak -e "s/BUCKET_NAME_PLACEHOLDER/${BUCKET_NAME}/" ${PWD}/backend.tf.example
mv ${PWD}/backend.tf.example ${PWD}/backend.tf
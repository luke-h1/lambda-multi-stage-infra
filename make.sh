#!/bin/bash

#
# variables
#

# AWS variables
AWS_PROFILE=default
AWS_REGION=eu-west-2
# project name
PROJECT_NAME=lambda-multi-stage-infra


# the directory containing the script file
dir="$(cd "$(dirname "$0")"; pwd)"
cd "$dir"


# log $1 in underline then $@ then a newline
under() {
    local arg=$1
    shift
    echo -e "\033[0;4m${arg}\033[0m ${@}"
    echo
}

usage() {
    under usage 'call the Makefile directly: make staging
      or invoke this file directly: ./make.sh staging'
}

create-env() {
    # check if user already exists (return something if user exists, otherwise return nothing)
    local exists=$(aws iam list-user-policies \
        --user-name $PROJECT_NAME \
        --profile $AWS_PROFILE \
        2>/dev/null)
        
    [[ -n "$exists" ]] && { echo abort user $PROJECT_NAME already exists; return; }

    # create a user named $PROJECT_NAME
    echo create iam user $PROJECT_NAME
    aws iam create-user \
        --user-name $PROJECT_NAME \
        --profile $AWS_PROFILE \
        1>/dev/null

    aws iam attach-user-policy \
        --user-name $PROJECT_NAME \
        --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
        --profile $AWS_PROFILE

    local key=$(aws iam create-access-key \
        --user-name $PROJECT_NAME \
        --query 'AccessKey.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey}' \
        --profile $AWS_PROFILE \
        2>/dev/null)

    local AWS_ACCESS_KEY_ID=$(echo "$key" | jq '.AccessKeyId' --raw-output)
    echo AWS_ACCESS_KEY_ID $AWS_ACCESS_KEY_ID
    
    local AWS_SECRET_ACCESS_KEY=$(echo "$key" | jq '.SecretAccessKey' --raw-output)
    echo AWS_SECRET_ACCESS_KEY $AWS_SECRET_ACCESS_KEY

    # envsubst tips : https://unix.stackexchange.com/a/294400
    # create .env file
    cd "$dir"
    # export variables for envsubst
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    envsubst < .env.tmpl > .env

    echo created file .env
}

# create env + terraform init
setup() {
    create-env
    # terraform init
    tf-init
}

# delete env + terraform destroy
delete() {
    # delete a user named $PROJECT_NAME
    echo delete iam user $PROJECT_NAME

    aws iam detach-user-policy \
        --user-name $PROJECT_NAME \
        --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
        --profile $AWS_PROFILE \
        2>/dev/null

    source "$dir/.env"
    aws iam delete-access-key \
        --user-name $PROJECT_NAME \
        --access-key-id $AWS_ACCESS_KEY_ID \
        2>/dev/null

    aws iam delete-user \
        --user-name $PROJECT_NAME \
        --profile $AWS_PROFILE

    cd "$dir"
    rm --force .env
    
    # terraform destroy
    tf-destroy
}

tf-init() {
    cd "$dir/terraform"
    terraform init
}

tf-validate() {
    cd "$dir/terraform"
    terraform fmt -recursive
	terraform validate
}

tf-apply() {
    cd "$dir/terraform"
    terraform plan -out=terraform.plan
    terraform apply -auto-approve terraform.plan
}

tf-destroy() {
    cd "$dir/terraform"
    terraform destroy \
        -auto-approve
}

# hello-staging
hello-staging() {
    cd "$dir/terraform"
    curl $(terraform output -raw hello_staging)
}

# hello-live
hello-live() {
    cd "$dir/terraform"
    curl $(terraform output -raw hello_live)
}



# if `$1` is a function, execute it. Otherwise, print usage
# compgen -A 'function' list all declared functions
# https://stackoverflow.com/a/2627461
FUNC=$(compgen -A 'function' | grep $1)
[[ -n $FUNC ]] && { echo execute $1; eval $1; } || usage;
exit 0
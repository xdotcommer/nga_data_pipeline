#!/usr/bin/env bash

docker compose down 
docker compose up -d                                                                                                                                           ─╯
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f terraform.tfstate*

tofu init
tofu plan -var="environment=local"

tofu apply -var="environment=local"


aws --endpoint-url=http://localhost:4566 stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:000000000000:stateMachine:nga-data-pipeline-pipeline-local

docker logs nga_data_pipeline-localstack-1


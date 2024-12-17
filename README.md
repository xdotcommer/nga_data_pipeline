# NGA Data Pipeline

A data pipeline for importing National Gallery of Art collection data into OpenSearch and S3.

## Requirements

- Docker & Docker Compose
- AWS CLI
- Terraform
- Ruby 3.2.5

## Local Development

### Environment setup:

```bash
brew install rbenv
rbenv install 3.2.5
rbenv local 3.2.5

bundle config set deployment true
bundle config set path 'vendor/bundle'
bundle lock --add-platform arm64-darwin-24
bundle install
```

### Start local services:

```bash
docker compose down
docker compose up -d
docker ps
```

You should see something similar to the following:

```bash
CONTAINER ID   IMAGE                                 COMMAND                  CREATED         STATUS                            PORTS                                                                NAMES
8cf6869214a0   opensearchproject/opensearch:latest   "./opensearch-docker…"   3 seconds ago   Up 3 seconds                      0.0.0.0:9200->9200/tcp, 9300/tcp, 0.0.0.0:9600->9600/tcp, 9650/tcp   nga_data_pipeline-opensearch-1
16e276ef6be2   localstack/localstack                 "docker-entrypoint.sh"   3 seconds ago   Up 3 seconds (health: starting)   4510-4559/tcp, 5678/tcp, 0.0.0.0:4566->4566/tcp
```

### Setup everything and test locally

Verify the notification email

```bash
aws ses verify-email-identity \
  --email-address aws-notify@novate.ai \
  --endpoint-url=http://localhost:4566

aws ses list-identities --endpoint-url=http://localhost:4566
```

Run the terraform scripts (local)

```bash
cd terraform
rm -rf .terraform/ .terraform.lock.hcl terraform.tfstate*

tofu init
tofu plan -var="environment=local"
tofu apply -var="environment=local"
```

You should see an output at the end with your localstack AWS resources

```bash
Apply complete! Resources: 18 added, 0 changed, 0 destroyed.

Outputs:

aws_region = "us-east-1"
data_backup_bucket = "nga-data-pipeline-data-backup-local"
environment = "local"
lambda_opensearch_importer_arn = "arn:aws:lambda:us-east-1:000000000000:function:nga-data-pipeline-opensearch-importer-local"
lambda_s3_importer_arn = "arn:aws:lambda:us-east-1:000000000000:function:nga-data-pipeline-s3-importer-local"
opensearch_endpoint = "https://localhost:9200"
sns_topic_arn = "arn:aws:sns:us-east-1:000000000000:nga-data-pipeline-import-notifications-local"
state_machine_arn = "arn:aws:states:us-east-1:000000000000:stateMachine:nga-data-pipeline-pipeline-local"
```

Trigger the event to start downloading and processing the data files

```bash
aws --endpoint-url=http://localhost:4566 stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:000000000000:stateMachine:nga-data-pipeline-pipeline-local
```

aws stepfunctions start-execution \
 --state-machine-arn arn:aws:states:us-east-1:YOURACCOUNTID:stateMachine:nga-data-pipeline-pipeline-demo

You'll get output on the event...

```json
{
  "executionArn": "arn:aws:states:us-east-1:000000000000:execution:nga-data-pipeline-pipeline-local:53623765-3eb5-4da7-94d2-108e18b02f11",
  "startDate": "2024-12-14T14:52:50.988312-05:00"
}
```

The process itself will take a minute or two.
It has to:

1. Pull the data files from github down to S3
2. Index those files in OpenSearch
3. Kick off an email notification that we're done

You can check the progress in local stack

```bash
docker compose logs localstack
```

Wait until you see something along the lines of

```bash
localstack-1  | 2024-12-14T23:40:36.246 DEBUG --- [et.reactor-0] l.services.ses.provider    : Email saved at: /tmp/localstack/localstack/state/ses/wruzseabnwriwdol-ldyqygxq-fusc-kshb-thno-dtijogepntle-jhqbzc.json
```

Now you should be able to use the search endpoint to query the NGA catalog

```bash
curl -k -u admin:$OPENSEARCH_INITIAL_ADMIN_PASSWORD -X GET "https://localhost:9200/nga-objects/_search" -H "Content-Type: application/json" -d '{
  "query": {
    "match": {
      "title": "Multiverse"
    }
  }
}'
```

You should see output like this for the curl command

```json
{
  "took": 12,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1,
      "relation": "eq"
    },
    "max_score": 17.088905,
    "hits": [
      {
        "_index": "nga-objects",
        "_id": "142055",
        "_score": 17.088905,
        "_source": {
          "id": "142055",
          "accession_number": "2009.115.1",
          "title": "Multiverse",
          "date": "2008",
          "medium": "light-emitting diodes (LEDs), computer, and electronic circuitry",
          "attribution": "Leo Villareal",
          "credit_line": "Gift of Victoria and Roger Sant and Sharon P. and Jay Rockefeller",
          "classification": "Time-Based Media Art",
          "description": "Commissioned from the artist by NGA; installed 2008 in the ceiling and walls of the Concourse walkway between the East and West Buildings of the National Gallery of Art.",
          "images": [
            {
              "uuid": "2b274686-7bd5-4e56-a4c5-5ef622d7d8a5",
              "iiif_url": "https://api.nga.gov/iiif/2b274686-7bd5-4e56-a4c5-5ef622d7d8a5",
              "thumbnail_url": "https://api.nga.gov/iiif/2b274686-7bd5-4e56-a4c5-5ef622d7d8a5/full/!200,200/0/default.jpg"
            }
          ]
        }
      }
    ]
  }
}
```

## AWS Deployment

Run the terraform scripts (demo)

```bash
cd terraform
rm -rf .terraform/ .terraform.lock.hcl terraform.tfstate*

tofu init
tofu plan -var="environment=demo"
tofu apply -var="environment=demo"
```

Trigger the event to start downloading and processing the data files

```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:YOURACCOUNTID:stateMachine:nga-data-pipeline-pipeline-demo
```

## Other Helpful Commands (Local)

```bash
# Show me the logfiles
docker compose logs localstack
docker compose logs opensearch

# Open a shell on localstack
docker compose exec localstack sh

# What S3 files do I have in the localstack
aws --endpoint-url=http://localhost:4566 s3 ls s3://nga-data-pipeline-data-backup-local --recursive

# More details about the OpenSearch instance and indexes...
curl -k -u admin:$OPENSEARCH_INITIAL_ADMIN_PASSWORD -X GET "https://localhost:9200/"
curl -k -u admin:$OPENSEARCH_INITIAL_ADMIN_PASSWORD -X GET "https://localhost:9200/nga-objects"
curl -k -u admin:$OPENSEARCH_INITIAL_ADMIN_PASSWORD -X GET "https://localhost:9200/_cluster/health"

# Something else
aws --profile novateai sts get-caller-identity
```

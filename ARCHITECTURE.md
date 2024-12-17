# NGA Data Pipeline Architecture

## Overview

AWS Step Functions pipeline importing National Gallery of Art collection data into OpenSearch and S3.

## Directory Structure

```
nga-data-pipeline/
├── ARCHITECTURE.md    # Architecture documentation
├── Dockerfile        # Container definition
├── Gemfile          # Ruby dependencies
├── README.md        # Setup and usage
├── docker-compose.yml # Local development services
├── nga/             # Core implementation
│   ├── open_search_indexer.rb # OpenSearch indexing
│   └── s3_importer.rb         # S3/Parquet storage
├── nga.rb           # Main entry point
├── spec/           # Test suite
│   └── fixtures/   # Test data
├── stepfunctions/  # AWS Step Functions
│   └── pipeline.json # Workflow definition
└── terraform/      # Infrastructure as code
```

## Components

### Core Modules (`nga/`)

- `s3_importer.rb`: CSV download and storage
- `open_search_indexer.rb`: Search indexing

### Infrastructure

- OpenSearch: Collection search
- S3: Raw/Parquet storage
- Step Functions: Orchestration
- SNS: Notifications

### Development

- Docker/LocalStack: Local AWS simulation
- RSpec: Testing
- Terraform: Infrastructure deployment

## Data Flow

1. Step Functions triggers parallel import
2. S3 module stores CSVs/Parquet
3. OpenSearch module indexes for search
4. SNS notification on completion
